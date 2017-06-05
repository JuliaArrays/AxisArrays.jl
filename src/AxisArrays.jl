__precompile__()

module AxisArrays

using Base: tail
using RangeArrays, IntervalSets
using Compat

export AxisArray, Axis, axisnames, axisvalues, axisdim, axes, atindex, atvalue

# From IntervalSets:
export ClosedInterval, ..
Base.@deprecate_binding Interval ClosedInterval

include("core.jl")
include("intervals.jl")
include("search.jl")
include("indexing.jl")
include("sortedvector.jl")
include("categoricalvector.jl")
include("combine.jl")

end
