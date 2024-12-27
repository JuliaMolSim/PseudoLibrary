using Downloads
using Tar
using TOML
using JSON3
using Dates
include("common.jl")

# Some hints and info how other people do this:
# [aiida-pseudo]: https://github.com/aiidateam/aiida-pseudo/blob/main/src/aiida_pseudo/groups/family/pseudo_dojo.py
# [pdojo_json]: https://github.com/abinit/pseudo_dojo/blob/master/website/nc-sr-04_pbe_standard.json
# nv: Number of valence shells

function get_extract_tarball(url)
    # Download and extract tarball file in current working directory
    withenv("JULIA_SSL_NO_VERIFY_HOSTS" => "*.pseudo-dojo.org") do
        bn = basename(url)
        Downloads.download(url, bn)
        run(`tar -xzf $bn`)
        rm(bn)
    end
end

function pseudodojo_djson_to_toml(meta, djson, toml)
    # meta:     pseudopotential collection meta
    # djson:    json file from pseudodojo
    # toml:     Toml file in which to store resulting parsed data

    data    = open(JSON3.read, djson, "r")
    element = first(splitext(basename(djson)))
    outmeta = Dict{String,Any}()

    #
    # Cutoff hints
    #
    if meta["type"] == "paw"
        # TODO I don't understand why, but [aiida-pseudo] does the same thing
        supersampling = sqrt(2.0)
    elseif meta["type"] == "nc"
        supersampling = 2.0
    else
        error("Do not know default supersampling for type $(meta["type"])")
    end

    if :hints in keys(data)
        # Normal hints (what all pseudos expose and what should be used by default)
        outmeta["Ecut"] = data[:hints][:normal][:ecut]
        outmeta["supersampling"] = supersampling

        # More fine-granular hints
        for key in (:low, :normal, :high)
            outmeta["cutoffs_$key"] = Dict(
                "Ecut"          => data[:hints][key][:ecut],
                "supersampling" => supersampling,
            )
        end
    else
        # Note, there is also :ppgen_hints, but these values are usually
        # *far too small*, so better not expose them.
        @warn "Could not find Ecut hints for: $element"
    end

    #
    # rcut values (use what QuantumEspresso is doing)
    #
    outmeta["rcut"] = 10.0  # Bohrs

    # Dump file
    open(io -> TOML.print(io, outmeta), toml, "w")
end

function download_pseudodojo(meta::AbstractDict, pseudopath)
    pseudofolder = meta["pseudodojo_handle"]
    check_valid_meta(meta, pseudofolder)

    pd_prefix = "http://www.pseudo-dojo.org/pseudos"
    # For the metadata URL, the final underscored part of the prefix
    # (the pseudo format) is replaced with `_djrepo`.
    metafolder = join(split(pseudofolder, "_")[1:end-1], "_") * "_djrepo"

    mktempdir() do d
        @info "Downloading files for $pseudofolder"
        cd(d) do
            get_extract_tarball(pd_prefix * "/" * pseudofolder * ".tgz")
            get_extract_tarball(pd_prefix * "/" *   metafolder * ".tgz")
        end

        # Some tarball extract with subdirectories, others don't
        if isdir(joinpath(d, metafolder))
            full_metafolder = joinpath(d, metafolder)
        else
            full_metafolder = d
        end
        if isdir(joinpath(d, pseudofolder))
            full_pseudofolder = joinpath(d, pseudofolder)
        elseif isdir(joinpath(d, join(split(pseudofolder, "_")[1:end-1], "_")))
            full_pseudofolder = joinpath(d, join(split(pseudofolder, "_")[1:end-1], "_"))
        else
            full_pseudofolder = d
        end

        outputfolder = joinpath(pseudopath, artifact_name(meta))
        @assert !isdir(outputfolder)  # Maybe we should add some update mechanism later

        @info "Extracting data to $outputfolder"
        mkdir(outputfolder)
        for fn in readdir(full_metafolder; join=true)
            if endswith(fn, ".djrepo")
                element = first(splitext(basename(fn)))
                pseudodojo_djson_to_toml(meta, fn, joinpath(outputfolder, element * ".toml"))
            end
        end

        copied_any = false
        for fn in readdir(full_pseudofolder)
            if endswith(fn, "." * meta["extension"])
                cp(joinpath(full_pseudofolder, fn), joinpath(outputfolder, fn))
                copied_any = true
            end
        end
        @assert copied_any

        open(joinpath(outputfolder, "meta.toml"), "w") do io
            d = copy(meta)
            d["extracted_on"] = string(Dates.now())
            TOML.print(io, d)
        end
    end  # Tempdir
end

#
#
#

function make_pd_meta_nc(version, relativistic, extra, functional)
    vstring = version
    if version == "0.4" && relativistic == "sr"
        # Version 0.4 for norm-conserving scalar relativistic does not exist
        # and is mapped to 0.4.1 on the website even though files are still
        # under the name of 0.4
        vstring = "0.4.1"
    end

    # For some reason this one is special:
    hfunctional = functional
    if functional == "lda" && version == "0.4"
        hfunctional = "pw"
    end
    pseudodojo_handle = ("nc-$(relativistic)-$(replace(version, "." => ""))_" *
                         "$(hfunctional)_$(extra)_upf")
    Dict(
        "collection"        => "dojo",
        "type"              => "nc",
        "relativistic"      => relativistic,
        "functional"        => functional,
        "version"           => vstring,
        "program"           => "oncvpsp3",
        "extra"             => [extra, ],
        "extension"         => "upf",
        "pseudodojo_handle" => pseudodojo_handle,
    )
end
function make_pd_meta_paw(version, relativistic, extra, functional)
    if version == "1.0"
        hfunctional = functional != "lda" ? functional : "pw"
        pseudodojo_handle = "paw_$(hfunctional)_$(extra)_xml"
    else
        pseudodojo_handle = ("paw-$(relativistic)-$(replace(version, "." => ""))_" *
                             "$(functional)_$(extra)_xml")
    end
    Dict(
        "collection"        => "dojo",
        "type"              => "paw",
        "relativistic"      => relativistic,
        "functional"        => functional,
        "version"           => version,
        "program"           => "jth",
        "extra"             => [extra, ],
        "extension"         => "xml",
        "pseudodojo_handle" => pseudodojo_handle,
    )
end

function main(pseudopath)
    mkpath(pseudopath)

    download_pseudodojo(make_pd_meta_nc("0.4", "fr", "standard",  "pbe"    ), pseudopath)
    download_pseudodojo(make_pd_meta_nc("0.4", "fr", "stringent", "pbe"    ), pseudopath)
    download_pseudodojo(make_pd_meta_nc("0.4", "fr", "standard",  "pbesol" ), pseudopath)
    download_pseudodojo(make_pd_meta_nc("0.4", "fr", "stringent", "pbesol" ), pseudopath)

    for functional in ("lda", "pbe", "pbesol"), extra in ("standard", "stringent")
        download_pseudodojo(make_pd_meta_nc("0.4", "sr", extra,  functional), pseudopath)
    end

    download_pseudodojo(make_pd_meta_nc("0.5", "sr", "standard",  "pbe"    ), pseudopath)
    download_pseudodojo(make_pd_meta_nc("0.5", "sr", "stringent", "pbe"    ), pseudopath)

    for functional in ("lda", "pbe", "pbesol"), extra in ("standard", "stringent")
        download_pseudodojo(make_pd_meta_paw("1.1", "sr", extra, functional), pseudopath)
    end
end

(abspath(PROGRAM_FILE) == @__FILE__) && main(ARGS[1])
