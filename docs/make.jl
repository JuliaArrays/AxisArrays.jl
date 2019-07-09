using Documenter, AxisArrays

makedocs(
    modules = [AxisArrays],
    sitename = "AxisArrays",
)

deploydocs(
    deps   = Deps.pip("mkdocs", "python-markdown-math"),
    repo   = "github.com/JuliaArrays/AxisArrays.jl.git"
)
