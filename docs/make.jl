using Documenter, AxisArrays

makedocs(
    modules = [AxisArrays],
    doctest = false
)

deploydocs(
    deps   = Deps.pip("mkdocs", "python-markdown-math"),
    repo   = "github.com/JuliaArrays/AxisArrays.jl.git",
    julia  = "0.5"
)
