using Documenter, AxisArrays

makedocs(
    modules = [AxisArrays],
)

deploydocs(
    deps   = Deps.pip("mkdocs", "python-markdown-math"),
    repo   = "github.com/JuliaArrays/AxisArrays.jl.git",
    julia  = "0.6"
)
