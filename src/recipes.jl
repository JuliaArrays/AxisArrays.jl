using RecipesBase

@recipe function plot(a::AxisArray) where {name}
    ax1 = AxisArrays.axes(a,1)
    xlabel --> axisname(ax1)
    if ndims(a) == 1
        ax1.val, a.data
    else
        ax2 = AxisArrays.axes(a,2)
        # Categorical axes print as a set of labelled series
        if axistrait(ax2) === Categorical
            for i in eachindex(ax2.val)
                @series begin
                    label --> "$(axisname(ax2)) $(ax2.val[i])"
                    ax1.val, a.data[:,i]
                end
            end
        else
            # Other axes as a 2D array
            ylabel --> axisname(ax2)
            seriestype --> :heatmap
            ax1.val, ax2.val, a.data
        end
    end
end

