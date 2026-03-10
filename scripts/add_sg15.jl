using Downloads
using Tar
using TOML
using JSON3
using Dates
include("common.jl")

function get_extract_tarball(url)
    # Download and extract tarball file in current working directory
    withenv("JULIA_SSL_NO_VERIFY_HOSTS" => "*.quantum-simulation.org") do
        bn = basename(url)
        Downloads.download(url, bn)
        run(`tar -xzf $bn`)
        rm(bn)
    end
end

function copy_element_to_collection(sourcefile, outputfolder)
    base = basename(sourcefile)
    element = first(split(base, "_"))

    elementmeta = Dict{String,Any}(
        "sg15_filename"       => base,
        "supersampling"       => 2.0,
        "Ecut"                => -1,  # = unknown
        "rcut"                => 10.0,  # Bohrs
    )
    # rcut values: We use what QuantumEspresso is doing, because the SG15 potentials
    # have been developed and verified using QE, where 10 is hard-coded

    # Construct filenames and dump files
    toml = joinpath(outputfolder, element * ".toml")
    upf  = joinpath(outputfolder, element * ".upf")

    open(io -> TOML.print(io, elementmeta), toml, "w")
    cp(sourcefile, upf)
end


function download_pseudodojo(meta::AbstractDict, pseudopath)
    sg_suffix = meta["sg_suffix"]
    check_valid_meta(meta, sg_suffix)

    sg15_url = "http://www.quantum-simulation.org/potentials/sg15_oncv/sg15_oncv_upf_2020-02-06.tar.gz"
    mktempdir() do d
        @info "Downloading files for $sg_suffix"
        cd(d) do
            get_extract_tarball(sg15_url)
        end
        outputfolder = joinpath(pseudopath, artifact_name(meta))
        @assert !isdir(outputfolder)  # Maybe we should add some update mechanism later

        @info "Extracting data to $outputfolder"
        mkdir(outputfolder)

        add_with_suffix = function (suffix, elements_done)
            elements_done
            for fn in readdir(d; join=true)
                if endswith(fn, suffix * ".upf")
                    base = basename(fn)
                    element = first(split(base, "_"))
                    if element in elements_done
                        continue
                    end

                    copy_element_to_collection(fn, outputfolder)
                    push!(elements_done, element)
                end
            end
            elements_done
        end

        elements_done = add_with_suffix(sg_suffix, String[])
        if meta["version"] == "1.1"
            # 1.1. only modifies some files, so fall back to 1.0 files
            # for those which did not not get modified
            elements_done = add_with_suffix(replace(sg_suffix, "1.1" => "1.0"), elements_done)
        end
        @assert !isempty(elements_done)
        @info "Found these elements." elements_done

        open(joinpath(outputfolder, "meta.toml"), "w") do io
            d = copy(meta)
            d["extracted_on"] = string(Dates.now())
            TOML.print(io, d)
        end
    end  # Tempdir
end

function make_sg15_meta(version, relativistic)
    rstring = Dict("sr" => "", "fr" => "_FR")[relativistic]
    sg_suffix = "ONCV_PBE$(rstring)-$(version)"

    Dict(
        "collection"   => "sg15",
        "type"         => "nc",
        "relativistic" => relativistic,
        "functional"   => "pbe",
        "version"      => version,
        "program"      => "oncvpsp2",
        "extra"        => ["canonical"],
        "extension"    => "upf",
        "sg_suffix"    => sg_suffix,
    )
end

function main(pseudopath)
    mkpath(pseudopath)

    for v in ("1.0", "1.1", "1.2")
        download_pseudodojo(make_sg15_meta(v, "sr"), pseudopath)
    end
    download_pseudodojo(make_sg15_meta("1.1", "fr"), pseudopath)
end

(abspath(PROGRAM_FILE) == @__FILE__) && main(ARGS[1])
