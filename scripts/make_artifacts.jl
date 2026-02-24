using Inflate
using LibGit2
using SHA
using Tar
include("common.jl")

LIBRARY_VERSION = "0.2.0"
REPO = "JuliaMolSim/PseudoLibrary"

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

    @assert isdir(pseudopath)
    folders = pseudo_folders(pseudopath)
    @info "Found pseudo folders:" folders

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
