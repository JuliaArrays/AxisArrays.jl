__precompile__()

module AxisArrays

using Base: tail
import Base.Iterators: repeated
using RangeArrays, IntervalSets
using IterTools

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
include("plots.jl")

end
