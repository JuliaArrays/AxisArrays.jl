@require DataFrames begin

    """
    Convert an AxisArray into a long-format DataFrame.
    
    ```julia
    DataFrame(a::AxisArray)
    ```
    
    ### Arguments
    
    * `a::AxisArray`
    
    ### Returns
    
    * `::DataFrame` : a DataFrame view into the AxisArray; columns are
      added for each axis plus one column for the data (named `:data`).

    """
    function Base.convert(::Type{DataFrames.DataFrame}, A::AxisArray)
        colnames = Symbol[axisnames(A)..., :data]
        sz = [1; size(A)...; 1]
        columns = Any[DataFrames.RepeatedVector(a, prod(sz[1:i]), prod(sz[i+2:end])) for (i,a) in enumerate(axes(A))]
        push!(columns, sub(A.data, 1:prod(sz)))
        DataFrames.DataFrame(columns, colnames)
    end

end


@require Gadfly begin

    import DataArrays
    ## Low-level code patching
    function Gadfly.Scale.discretize_make_pda(values::DataFrames.RepeatedVector, levels=nothing)
        if levels == nothing
            return DataArrays.PooledDataArray(values)
        else
            return DataArrays.PooledDataArray(values[:], levels)
        end
    end

    """
    Plot an AxisArray using Gadfly.
    
    ```julia
    Gadfly.plot(A::AxisArray, args...; kargs...)
    ```
    
    ### Arguments
    
    * `A::AxisArray`

    All other arguments are passed to Gadfly.plot.
    
    ### Examples
    
    ```julia
    using Gadfly
    A = AxisArray(reshape([1:24], 12,2), (.1:.1:1.2, [:a,:b]))
    plot(A, x = :row, y = :data, color = :col)
    ```

    """
    Gadfly.plot(A::AxisArray, args...; kwargs...) = Gadfly.plot(DataFrames.DataFrame(A), args...; kwargs...)
    
end
