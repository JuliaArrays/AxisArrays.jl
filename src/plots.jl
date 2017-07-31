using RecipesBase

@recipe function plot{T}(arr::AxisArray{T, 1})
    xlabel --> axisnames(arr)[1]
    xrotation --> -45
    xs = first(axisvalues(arr))
    xs, arr.data
end

@recipe function plot{T}(arr::AxisArray{T, 2})
    xlbl, ylbl = axisnames(arr)
    xlabel --> xlbl
    ylabel --> ylbl
    xrotation --> -45
    axisvalues(arr)..., arr.data
end
