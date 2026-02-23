using Inflate
using LibGit2
using PeriodicTable
using SHA
using Tar
using TOML
include("common.jl")

LIBRARY_VERSION = "0.2.0"
REPO = "JuliaMolSim/PseudoLibrary"

function collect_meta(folder)
    meta = open(TOML.parse, joinpath(folder, "meta.toml"), "r")
    elements = String[]

    for element in getproperty.(PeriodicTable.elements, :symbol)
        if isfile(joinpath(folder, element * "." * meta["extension"]))
            push!(elements, element)
        end
    end
    meta["elements"] = elements

    check_valid_meta(meta, folder)
    meta
end

function pseudo_folders(path)
    [root for (root, dirs, files) in walkdir(path) if "meta.toml" in files]
end

function determine_version()
    if startswith(get(ENV, "GITHUB_REF", ""), "refs/tags/")
        @assert startswith(ENV["GITHUB_REF_NAME"], "v")
        version_from_tag = ENV["GITHUB_REF_NAME"][2:end]
        if version_from_tag != LIBRARY_VERSION
            error("Tag version and expected library version do not agree.")
        end
        return version_from_tag
    else
        return LIBRARY_VERSION
    end
end

function main(pseudopath, output)
    version = determine_version()
    @info "Determined pseudolibrary release: $version"

    folders = pseudo_folders(pseudopath)
    @info "Found pseudo folders:" folders

    @assert isdir(pseudopath)
    @assert !isdir(output)
    mkpath(output)

    artifacts = Dict{String,Any}()
    for folder in folders
        meta = collect_meta(folder)
        name = artifact_name(meta)

        targetfile = joinpath(output, "$(name).tar.gz")
        @info "Generating $targetfile"
        folder = abspath(folder)
        targetfile = abspath(targetfile)
        cd(folder) do
            files = [e * "." * meta["extension"] for e in meta["elements"]]
            @assert all(isfile, files)
            for e in meta["elements"]
                if isfile(e * ".toml")
                    push!(files, e * ".toml")
                end
            end
            files = sort(files)

            withenv("GZIP" => -9) do # Increase compression level
                run(`tar --use-compress-program="pigz -k" -cf $targetfile $(files)`)
            end
        end

        meta["git-tree-sha1"] = Tar.tree_hash(IOBuffer(inflate_gzip(targetfile)))
        meta["lazy"] = true
        meta["download"] = [Dict(
            "url" => "https://github.com/$REPO/releases/download/v$version/$name.tar.gz",
            "sha256" => bytes2hex(open(sha256, targetfile))
        )]

        meta["pseudolibrary_version"] = version
        artifacts[name] = meta
    end

    @info "Generating $(joinpath(output, "Artifacts.toml"))"
    open(joinpath(output, "Artifacts.toml"), "w") do io
        TOML.print(io, artifacts)
    end
end

(abspath(PROGRAM_FILE) == @__FILE__) && main(ARGS[1], ARGS[2])
