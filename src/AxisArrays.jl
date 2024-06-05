VERSION < v"0.7.0-beta2.199" && __precompile__()

module AxisArrays

using ArrayInterface
using Base: tail
import Base.Iterators: repeated
using RangeArrays, IntervalSets
using IterTools
using Dates
using Static

function axes end

export AxisArray, Axis, AxisMatrix, AxisVector
export axisnames, axisvalues, axisdim, axes, atindex, atvalue, collapse

# From IntervalSets:
export ClosedInterval, ..

include("core.jl")
include("intervals.jl")
include("search.jl")
include("indexing.jl")
include("sortedvector.jl")
include("categoricalvector.jl")
include("combine.jl")

end
