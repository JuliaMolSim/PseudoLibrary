using Tar, Inflate, SHA, TOML

ENV["GZIP"] = -9

artifacts = Dict()
for family in readdir("pseudos")
    fullpath = joinpath("pseudos", family)
    isdir(fullpath) || continue
    outpath = joinpath(pwd(), "artifacts", "$(family).tar.gz")
    cd(fullpath) do
        run(`tar --use-compress-program="pigz -k" -cvzf $outpath $(readdir())`)
    end
    artifact_name = family
    artifacts[family] = Dict(
        "git-tree-sha1" => Tar.tree_hash(IOBuffer(inflate_gzip(outpath))),
        "lazy" => true,
        "download" => [Dict(
            "url" => "https://github.com/JuliaMolSim/PseudoLibrary/raw/main/artifacts/$(family).tar.gz",
            "sha256" => bytes2hex(open(sha256, outpath))
        )]
    )
end

open("Artifacts.toml", "w") do io
    TOML.print(io, artifacts)
end
