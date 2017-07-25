using RecipesBase

@recipe function plot{T}(arr::AxisArray{T, 1})
    xlabel --> axisnames(arr)[1]
    xticks --> axisvalues(arr)[1]
    arr.data
end

@recipe function plot{T}(arr::AxisArray{T, 2})
    xlbl, ylbl = axisnames(arr)
    xlabel --> xlbl
    ylabel --> ylbl
    axisvalues(arr)..., arr.data
end
