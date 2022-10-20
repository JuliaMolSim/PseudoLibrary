for suite in readdir("pseudos")
    fullpath = joinpath("pseudos", suite)
    isdir(fullpath) || continue
    outpath = joinpath(pwd(), "artefacts", "$(suite).tar.gz")
    cd(fullpath) do
        run(`tar cvzf $outpath $(readdir())`)
    end
end
