module AxisArrays

using Requires, Tuples, RangeArrays

export AxisArray, Axis, Interval, axisnames, axisvalues, axisdim, axes, .., atindex

include("core.jl")
include("intervals.jl")
include("search.jl")
include("indexing.jl")
include("sortedvector.jl")
include("cat.jl")
include("utils.jl")

end
