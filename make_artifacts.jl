ENV["GZIP"] = -9

for family in readdir("pseudos")
    fullpath = joinpath("pseudos", family)
    isdir(fullpath) || continue
    outpath = joinpath(pwd(), "artifacts", "$(family).tar.gz")
    cd(fullpath) do
        run(`tar cvzf $outpath $(readdir())`)
    end
end
