module AxisArrays

using Requires, Tuples, RangeArrays, Iterators, Compat

export AxisArray, Axis, Interval, axisnames, axisvalues, axisdim, axes, .., atindex

include("core.jl")
include("intervals.jl")
include("search.jl")
include("indexing.jl")
include("sortedvector.jl")
include("combine.jl")
include("utils.jl")

end
