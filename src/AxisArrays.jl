module AxisArrays

using Requires

export AxisArray, Axis, Interval, axisnames, axisvalues, axisdim, axes

include("core.jl")
include("intervals.jl")
include("indexing.jl")
include("utils.jl")

end
