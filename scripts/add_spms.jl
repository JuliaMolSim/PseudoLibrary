using Tar
using LibGit2
using TOML
using JSON3
using Dates
include("common.jl")

const num_regex = r"([+\-]?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+\-]?\d+)?)"

function download_spms(meta, pseudopath)
    repo_url = "https://github.com/SPARC-X/SPMS-psps.git"
    commit_hash = "4bdd7ba28d5d1a61262e639307108ca081e8d6f8"

    extension = meta["extension"]
    pseudofolder = extension
    check_valid_meta(meta, pseudofolder)

    mktempdir() do d
        @info "Downloading files for SPMS $extension"
        repo = LibGit2.clone(repo_url, d)
        LibGit2.checkout!(repo, commit_hash)

        full_pseudofolder = joinpath(d, pseudofolder)
        outputfolder = joinpath(pseudopath, artifact_name(meta))
        @assert !isdir(outputfolder)  # Maybe we should add some update mechanism later

        @info "Extracting data to $outputfolder"
        mkdir(outputfolder)
        for fn in readdir(full_pseudofolder; join=true)
            if endswith(fn, extension)
                element = split(basename(fn), "_")[2]
                spms_psp_to_toml(fn, joinpath(outputfolder, element * ".toml"))
            end
        end

        copied_any = false
        for n in readdir(full_pseudofolder)
            if endswith(n, "." * extension)
                element = split(basename(n), "_")[2]
                cp(joinpath(full_pseudofolder, n), joinpath(outputfolder, element * "." * extension))
                copied_any = true
            end
        end
        @assert copied_any

        open(joinpath(outputfolder, "meta.toml"), "w") do io
            d = copy(meta)
            d["extracted_on"] = string(Dates.now())
            TOML.print(io, d)
        end
    end
end

function spms_psp_to_toml(psp, toml)
    log10_accuracy = Dict(
        "low" => log10(1e-3),
        "high" => log10(1e-4),
    )
    default_accuracy = "high"  # Better safe than sorry
    supersampling = 2.0  # Norm-conserving value
    rcut = 5.99  # So that UPFs are interpreted equivalently to PSP8s
    outmeta = Dict{String,Any}()
    Ecuts = open(psp) do io
        text = read(io, String)
        collect(eachmatch(
            r"Ecut \(" * num_regex * r" Ha/atom accuracy\):\s+" * num_regex * r" Ha",
            text
        ))
    end
    for Ecut in Ecuts
        for (key, acc) in log10_accuracy
            if log10(parse(Float64, Ecut[1])) ≈ acc
                outmeta["cutoffs_" * key] = Dict(
                    "Ecut"          => parse(Float64, Ecut[2]),
                    "supersampling" => supersampling,
                )
            end
        end
    end
    outmeta["Ecut"] = outmeta["cutoffs_" * default_accuracy]["Ecut"]
    outmeta["supersampling"] = supersampling
    outmeta["rcut"] = rcut
    # Dump file
    open(io -> TOML.print(io, outmeta), toml, "w")
end

function make_spms_meta(extension)
    Dict(
        "collection"   => "spms",
        "type"         => "nc",
        "relativistic" => "sr",
        "functional"   => "pbe",
        "version"      => "1.0",
        "program"      => "oncvpsp4",
        "extension"    => extension,
        "extra"        => ["canonical"],
    )
end

function main(pseudopath)
    mkpath(pseudopath)
    download_spms(make_spms_meta("upf"), pseudopath)
    download_spms(make_spms_meta("psp8"), pseudopath)
end

(abspath(PROGRAM_FILE) == @__FILE__) && main(ARGS[1])
