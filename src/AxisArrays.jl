module AxisArrays

using Requires, TupleTypes

export AxisArray, Axis, Interval, axisnames, axisvalues, axisdim, axes

include("core.jl")
include("intervals.jl")
include("indexing.jl")
include("sortedvector.jl")
include("utils.jl")

end
