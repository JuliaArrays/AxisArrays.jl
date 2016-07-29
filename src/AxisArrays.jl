module AxisArrays

using Tuples, RangeArrays, Iterators, Compat
using Compat.view

export AxisArray, Axis, Interval, axisnames, axisvalues, axisdim, axes, .., atindex

include("core.jl")
include("intervals.jl")
include("search.jl")
include("indexing.jl")
include("sortedvector.jl")
include("combine.jl")

end
