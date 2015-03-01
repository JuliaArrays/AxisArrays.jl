module AxisArrays

using Requires

export AxisArray, Axis, Interval, axisnames, axisdim, axes,
       moving, merge

include("core.jl")
include("intervals.jl")
include("indexing.jl")
include("utils.jl")
include("timeseries.jl")

end
