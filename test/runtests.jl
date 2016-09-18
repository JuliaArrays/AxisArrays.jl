using AxisArrays
using Base.Test, Compat

@test isempty(detect_ambiguities(AxisArrays, Base, Core))

include("core.jl")
include("intervals.jl")
include("indexing.jl")
include("sortedvector.jl")
include("search.jl")
include("combine.jl")

nothing
