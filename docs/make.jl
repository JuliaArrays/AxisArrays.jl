using Documenter, AxisArrays

makedocs(
    modules = [AxisArrays],
    sitename = "AxisArrays",
)

deploydocs(
    repo   = "github.com/JuliaArrays/AxisArrays.jl.git"
)
