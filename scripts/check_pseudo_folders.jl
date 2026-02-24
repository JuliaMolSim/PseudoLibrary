# Go over all pseudo folders and check that the folder name agrees with the
# future artifact name and perform some basic checks (e.g. that the metadata is valid).
#
# Use from root folder of repo as
#      julia --project=scripts scripts/check_pseudo_folders.jl pseudos

include("common.jl")

function main(pseudopath)
    @assert isdir(pseudopath)

    folders = pseudo_folders(pseudopath)
    @info "Found pseudo folders:" folders
    for folder in folders
        # collect_meta also checks the metadata for consistency
        meta = collect_meta(folder)
        name = artifact_name(meta)

        if name != basename(folder)
            error("Artifact name does not agree with folder name (in $folder)")
        end
    end
end

(abspath(PROGRAM_FILE) == @__FILE__) && main(ARGS[1])
