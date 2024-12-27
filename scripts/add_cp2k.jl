using Dates
using LibGit2
using PeriodicTable
using Printf
using TOML
include("common.jl")

# Note: This is not exactly the definition of rare earth metals,
# but the one which is most useful for categorising the pseudopotentials here
is_rare_earth(element) = (58 ≤ element.number ≤ 71) || (89 ≤ element.number ≤ 103)

struct LargeCore end
struct SemiCore  end
struct SmallCore end
const coremap = Dict("smallcore" => SmallCore(),
                     "semicore"  => SemiCore(),
                     "largecore" => LargeCore())

#             main group       TM until Ni      TM from Cu        rare earth metals
# LargeCore          4sp           3d + 4sp             4sp          4f + 5sp + 6s
# SemiCore      3d + 4sp         3spd + 4sp        3d + 4sp          4f + 5sp + 6s
# SmallCore     3d + 4sp         3spd + 4sp      3spd + 4sp       4spdf + 5sp + 6s
function n_valence_electrons(::LargeCore, element::Element)
    if element.number ≤ 2
        return element.number
    elseif is_rare_earth(element)     # Rare earth
        return element.xpos + 8       # 4f + 5sp + 6s
    elseif element.xpos ≤ 10          # before group 10 = Ni
        return element.xpos           # 3d + 4sp
    elseif element.xpos > 10          # after group 11 = Cu
        return element.xpos - 10      # 4sp
    end
    error("Could not determine valence electrons for $(element.symbol)")
end

function n_valence_electrons(::SemiCore, element::Element)
    if element.number ≤ 4
        return element.number
    elseif is_rare_earth(element)
        return n_valence_electrons(LargeCore(), element)
    elseif element.xpos ≤ 10          # before group 10 = Ni
        return element.xpos + 8       # 3spd + 4sp
    elseif element.xpos > 10          # after group 11 = Cu
        return element.xpos           # 3d + 4sp
    end
    error("Could not determine valence electrons for $(element.symbol)")
end

function n_valence_electrons(::SmallCore, element::Element)
    if element.number ≤ 4
        return element.number
    elseif is_rare_earth(element)     # Rare earth
        return element.xpos + 8 + 18  # 4spdf + 5sp + 6s
    else
        return element.xpos + 8       # 3spd + 4sp
    end
end

nextcore(::SmallCore,  element) = SemiCore()
nextcore(::LargeCore, element)  = SemiCore()
function nextcore(::SemiCore, element)
    if element.xpos ≥ 13 && !is_rare_earth(element)
        return LargeCore()
    else
        error("SemiCore $element")
    end
end

function matching_cp2k_pseudofile(pseudofolder, coretype, element::Element)
    nv = n_valence_electrons(coretype, element)
    pseudofile = joinpath(pseudofolder, "$(element.symbol)-q$nv")
    if isfile(pseudofile)
        return (; pseudofile, nv)
    else
        return matching_cp2k_pseudofile(pseudofolder, nextcore(coretype, element), element)
    end
end

function update_git_repo(upstreampath)
    repo_url = "https://github.com/cp2k/cp2k-data"
    local_folder = joinpath(upstreampath, "cp2k-data")

    if isdir(local_folder)
        repo = LibGit2.GitRepo(local_folder)
        LibGit2.fetch(repo)
        LibGit2.rebase!(repo)
    else
        @info "Cloning cp2k git repo"
        mkpath(upstreampath)
        repo = LibGit2.clone(repo_url, local_folder)
    end
    return local_folder
end

function collect_all_elements(pseudofolder)
    # File names are of the form Zn-q10 and similar
    all_elements = [first(split(fn, "-")) for fn in readdir(pseudofolder)
                    if occursin("-q", fn)]
    unique(sort(all_elements))
end

#
#
#

function download_goedecker(meta::AbstractDict,
                            pseudopath,
                            upstreampath=joinpath(pseudopath, "..", "upstream"))
    check_valid_meta(meta, meta["cp2k_data_handle"])
    pseudofolder = joinpath(update_git_repo(upstreampath), meta["cp2k_data_handle"])

    outputfolder = joinpath(pseudopath, artifact_name(meta))
    @assert !isdir(outputfolder)  # Maybe we should add some update mechanism later

    all_elements = collect_all_elements(pseudofolder)
    @info "Extracting data to $(basename(outputfolder))"
    mkdir(outputfolder)
    for element in all_elements
        ptable_element = elements[Symbol(element)]
        (; pseudofile, nv) = matching_cp2k_pseudofile(pseudofolder,
                                                      coremap[first(meta["extra"])],
                                                      ptable_element)
        rfile = relpath(pseudofile, pseudofolder)

        elementmeta = Dict(
            "cp2k_filename"       => rfile,
            "n_valence_electrons" => nv,
            "supersampling"       => 2.0,
            "Ecut"                => -1,  # = unknown
        )
        open(joinpath(outputfolder, "$(element).toml"), "w") do io
            TOML.print(io, elementmeta)
        end

        cp(pseudofile, joinpath(outputfolder, "$(element).$(meta["extension"])"))
    end

    open(joinpath(outputfolder, "meta.toml"), "w") do io
        d = copy(meta)
        d["extracted_on"] = string(Dates.now())
        TOML.print(io, d)
    end
end

function dump_goedecker_pseudo_mapping(meta::AbstractDict,
                                       pseudopath,
                                       upstreampath=joinpath(pseudopath, "..", "upstream"))
    pseudofolder = joinpath(update_git_repo(upstreampath), meta["cp2k_data_handle"])

    element_sort(element) = elements[Symbol(element)].number
    all_elements = sort(collect_all_elements(pseudofolder); by=element_sort)

    fn = join((meta["collection"], meta["type"], meta["relativistic"],
               meta["functional"], "v" * replace(meta["version"], "." => "_"), "md"), ".")
    @info "Writing pseudo mapping to $fn"
    open(joinpath(pseudopath, fn), "w") do io
        @printf io " %-5s | %-14s | %-14s | %-14s\n" "atnum" "largecore" "semicore" "smallcore"
        @printf io " %.5s | %-14s | %-14s | %-14s\n" "-"^5 "-"^14 "-"^14 "-"^14
        for element in all_elements
            ptable_element = elements[Symbol(element)]
            large = relpath(matching_cp2k_pseudofile(pseudofolder, LargeCore(),
                                                     ptable_element).pseudofile, pseudofolder)
            semi  = relpath(matching_cp2k_pseudofile(pseudofolder, SemiCore(),
                                                     ptable_element).pseudofile, pseudofolder)
            small = relpath(matching_cp2k_pseudofile(pseudofolder, SmallCore(),
                                                     ptable_element).pseudofile, pseudofolder)

            ss = string(ptable_element.number)
            @printf io " %-5s | %-14s | %-14s | %-14s\n" ss large semi small
        end
    end
    nothing
end
function dump_goedecker_pseudo_mapping(functional::AbstractString, version, pseudopath, args...)
    dump_goedecker_pseudo_mapping(make_gth_meta(functional, "largecore", version),
                                  pseudopath, args...)
end

function make_gth_meta(functional, extra, version)
    @assert extra in ("smallcore", "semicore", "largecore")
    @assert functional in ("lda", "pbe", "blyp")

    hfunctional = functional
    if functional == "lda"
        hfunctional = "pade"
    end
    Dict(
        "collection"        => "cp2k",
        "type"              => "nc",
        "relativistic"      => "sr",
        "functional"        => functional,
        "version"           => version,
        "program"           => "pseudo2.3",
        "extra"             => [extra, ],
        "extension"         => "gth",
        "cp2k_data_handle"  => "potentials/Goedecker/cp2k/$hfunctional",
    )
end

function main(pseudopath)
    mkpath(pseudopath)

    # Note: This is "our" internal version as there is no upstream version information available
    version = "0.1"
    for functional in ("lda", "pbe")
        dump_goedecker_pseudo_mapping(functional, version, pseudopath)
        download_goedecker(make_gth_meta(functional, "smallcore", version), pseudopath)
        download_goedecker(make_gth_meta(functional, "semicore",  version), pseudopath)
        download_goedecker(make_gth_meta(functional, "largecore", version), pseudopath)
    end
end

(abspath(PROGRAM_FILE) == @__FILE__) && main(ARGS[1])
