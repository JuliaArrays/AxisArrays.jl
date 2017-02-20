using AxisArrays
using Base.Test

if VERSION < v"0.6.0-dev"
    @test isempty(detect_ambiguities(AxisArrays, Base, Core))
end

include("core.jl")
include("intervals.jl")
include("indexing.jl")
include("sortedvector.jl")
include("search.jl")
include("combine.jl")

include("readme.jl")

nothing
