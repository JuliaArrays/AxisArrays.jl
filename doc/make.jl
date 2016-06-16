using Documenter, AxisArrays

makedocs(
    modules = [AxisArrays],
    doctest = false
)

deploydocs(
    deps   = Deps.pip("mkdocs", "python-markdown-math"),
    repo   = "github.com/mbauman/AxisArrays.jl.git",
    julia  = "release"
)
