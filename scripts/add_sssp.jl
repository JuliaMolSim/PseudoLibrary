using Downloads
using HTTP
using Tar
using TOML
using JSON3
using YAML
using Dates
include("common.jl")

FIRST_RECORD_ID = "e67tc-6b197"
FUNCTIONAL_MAP = Dict("pbe" => "PBE", "pbesol" => "PBEsol")

function get_extract_tarball(url)
    # Download and extract tarball file in current working directory
    withenv("JULIA_SSL_NO_VERIFY_HOSTS" => "*.materialscloud.org") do
        bn = basename(url)
        Downloads.download(url, bn)
        run(`tar -xzf $bn`)
        rm(bn)
    end
end

function download_sssp(meta::AbstractDict, pseudopath)
    pseudofolder = meta["sssp_handle"]
    check_valid_meta(meta, pseudofolder)

    # Get the id of the latest record version
    url_latest_record = "https://archive.materialscloud.org/api/records/$FIRST_RECORD_ID/versions/latest"
    response = HTTP.request("GET", url_latest_record)
    latest_record_id = JSON3.read(response.body)[:id]
    @info "Latest record id: $latest_record_id"

    functional_name = FUNCTIONAL_MAP[meta["functional"]]
    filename_base = "SSSP_$(meta["version"])_$(functional_name)_$(meta["extra"][1])"
    url_archive = "https://archive.materialscloud.org/api/records/$latest_record_id/files/$filename_base.tar.gz/content"
    url_metadata = "https://archive.materialscloud.org/api/records/$latest_record_id/files/$filename_base.json/content"

    outputfolder = joinpath(pseudopath, artifact_name(meta))
    mkdir(outputfolder)

    mktempdir() do d
        @info "Downloading archive from $url_archive"
        cd(d) do
            get_extract_tarball(url_archive)
        end

        @info "Downloading metadata from $url_metadata"
        metadata_path = joinpath(d, "$filename_base.json")
        Downloads.download(url_metadata, metadata_path)
        metadata = open(JSON3.read, metadata_path, "r")

        for fn in readdir(d; join=true)
            bn = basename(fn)
            if endswith(fn, ".UPF") || endswith(fn, ".upf")
                element = findfirst(v -> v[:filename] == bn, metadata)
                cp(fn, joinpath(outputfolder, String(element) * "." * meta["extension"]))
                open(joinpath(outputfolder, String(element) * ".toml"), "w") do io
                    Ecut_wfc_Ry = metadata[element][:cutoff_wfc]
                    Ecut_rho_Ry = metadata[element][:cutoff_rho]
                    TOML.print(
                        io,
                        Dict(
                            "Ecut" => Ecut_wfc_Ry / 2,  # Convert from Ry to Ha
                            "supersampling" => sqrt(Ecut_rho_Ry / Ecut_wfc_Ry),
                            # TODO: eventually add "source_family", etc. as API-level metadata keys
                            "sssp_pseudopotential" => metadata[element][:pseudopotential],  # original pseudo family
                            "sssp_filename" => metadata[element][:filename],  # original file name
                            "sssp_md5" => metadata[element][:md5],  # md5 hash of the file
                        )
                    )
                end
            end
        end
    end

    open(joinpath(outputfolder, "meta.toml"), "w") do io
        d = copy(meta)
        d["extracted_on"] = string(Dates.now())
        TOML.print(io, d)
    end
end

function make_sssp_meta(version, functional, protocol)
    Dict(
        "collection" => "sssp",
        "type" => "mixed",
        "relativistic" => "sr",
        "functional" => functional,
        "version" => version,
        "program" => "mixed",
        "extra" => [protocol],
        "extension" => "upf",
        "sssp_handle" => "$(functional)_$(protocol)_$(replace(version, "." => "-"))",
    )
end

function main(pseudopath)
    mkdir(pseudopath)
    download_sssp(make_sssp_meta("1.3.0", "pbe", "efficiency"), pseudopath)
    download_sssp(make_sssp_meta("1.3.0", "pbe", "precision"), pseudopath)
    download_sssp(make_sssp_meta("1.3.0", "pbesol", "efficiency"), pseudopath)
    download_sssp(make_sssp_meta("1.3.0", "pbesol", "precision"), pseudopath)
end

(abspath(PROGRAM_FILE) == @__FILE__) && main(ARGS[1])
