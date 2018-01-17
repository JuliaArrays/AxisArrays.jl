__precompile__()

module AxisArrays

using Base: tail
import Base.Iterators: repeated
using RangeArrays, IntervalSets
using IterTools
using Compat
using Compat.Dates
using Compat: AbstractRange

export AxisArray, Axis, axisnames, axisvalues, axisdim, axes, atindex, atvalue, collapse

# From IntervalSets:
export ClosedInterval, ..

include("core.jl")
include("intervals.jl")
include("search.jl")
include("indexing.jl")
include("sortedvector.jl")
include("categoricalvector.jl")
include("combine.jl")
@static if VERSION >= v"0.7.0-DEV.2638"
    include("broadcast.jl")
end

end
