module AxisArrays

using Requires

export AxisArray, Axis, Interval, axisnames, axisdim, axes

include("core.jl")
include("intervals.jl")
include("indexing.jl")
include("utils.jl")
include("time/timeseries.jl")

end
