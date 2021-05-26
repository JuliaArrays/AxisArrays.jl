if isdefined(OffsetArrays, :centered)
    # Compat for OffsetArrays v1.9
    # https://github.com/JuliaArrays/OffsetArrays.jl/pull/242
    OffsetArrays.centered(ax::Axis{name}) where name = Axis{name}(OffsetArrays.centered(ax.val))
    OffsetArrays.centered(a::AxisArray) = AxisArray(OffsetArrays.centered(a.data), OffsetArrays.centered.(AxisArrays.axes(a)))
end
