__precompile__()

module AxisArrays

using Base: tail
using RangeArrays, IntervalSets

export AxisArray, Axis, axisnames, axisvalues, axisdim, axes, atindex, atvalue

# From IntervalSets:
export ClosedInterval, ..

include("core.jl")
include("intervals.jl")
include("search.jl")
include("indexing.jl")
include("sortedvector.jl")
include("combine.jl")

end
