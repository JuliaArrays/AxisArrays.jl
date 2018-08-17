function equalvalued(X::NTuple)
    n = length(X)
    allequal = true
    i = 2
    while allequal && i <= n
        allequal = X[i] == X[i-1]
        i += 1
    end #while
    return allequal
end #equalvalued

sizes(As::AxisArray...) = tuple(zip(map(a -> map(length, Base.axes(a)), As)...)...)
matchingdims(As::Tuple{Vararg{AxisArray}}) = all(equalvalued, sizes(As...))
matchingdimsexcept(As::Tuple{Vararg{AxisArray}}, n::Int) = all(equalvalued, sizes(As...)[[1:n-1; n+1:end]])

Base.cat(As::AxisArray{T}...; dims) where {T} = _cat(dims, As...)
_cat(::Val{n}, As...) where {n} = _cat(n, As...)

@inline function _cat(n::Integer, As...)
    if n <= ndims(As[1])
        matchingdimsexcept(As, n) || error("All non-concatenated axes must be identically-valued")
        newaxis = Axis{axisnames(As[1])[n]}(vcat(map(A -> A.axes[n].val, As)...))
        checkaxis(newaxis)
        return AxisArray(cat(map(A->A.data, As)..., dims=n), (As[1].axes[1:n-1]..., newaxis, As[1].axes[n+1:end]...))
    else
        matchingdims(As) || error("All axes must be identically-valued")
        return AxisArray(cat(map(A->A.data, As)..., dims=n), As[1].axes)
    end #if
end

function axismerge(method::Symbol, axes::Axis{name,T}...) where {name,T}

    axisvals = if method == :inner
        intersect(axisvalues(axes...)...)
    elseif method == :left
        axisvalues(axes[1])[1]
    elseif method == :right
        axisvalues(axes[end])[1]
    elseif method == :outer
        union(axisvalues(axes...)...)
    else
        error("Join method must be one of :inner, :left, :right, :outer")
    end #if

    isa(axistrait(axisvals), Dimensional) && sort!(axisvals)

    return Axis{name}(collect(axisvals))

end

function indexmappings(oldaxes::NTuple{N,Axis}, newaxes::NTuple{N,Axis}) where N
    oldvals = axisvalues(oldaxes...)
    newvals = axisvalues(newaxes...)
    return collect(zip(indexmapping.(oldvals, newvals)...))
end

function indexmapping(old::AbstractVector, new::AbstractVector)

    before = Int[]
    after = Int[]

    oldperm = sortperm(old)
    newperm = sortperm(new)

    oldsorted = old[oldperm]
    newsorted = new[newperm]

    oldlength = length(old)
    newlength = length(new)

    oi = ni = 1

    while oi <= oldlength && ni <= newlength

        oldval = oldsorted[oi]
        newval = newsorted[ni]

        if oldval == newval
            push!(before, oldperm[oi])
            push!(after, newperm[ni])
            oi += 1
            ni += 1
        elseif oldval < newval
            oi += 1
        else
            ni += 1
        end

    end

    return before, after

end

"""
    merge(As::AxisArray...)

Combines AxisArrays with matching axis names into a single AxisArray spanning all of the axis values of the inputs. If a coordinate is defined in more than ones of the inputs, it takes its value from last input in which it appears. If a coordinate in the output array is not defined in any of the input arrays, it takes the value of the optional `fillvalue` keyword argument (default zero).
"""
function Base.merge(As::AxisArray{T,N,D,Ax}...; fillvalue::T=zero(T)) where {T,N,D,Ax}

    resultaxes = map(as -> axismerge(:outer, as...), map(tuple, axes.(As)...))
    resultdata = fill(fillvalue, length.(resultaxes)...)
    result = AxisArray(resultdata, resultaxes...)

    for A in As
        before_idxs, after_idxs = indexmappings(A.axes, result.axes)
        result.data[after_idxs...] = A.data[before_idxs...]
    end

    return result

end #merge

"""
    join(As::AxisArray...)

Combines AxisArrays with matching axis names into a single AxisArray. Unlike `merge`, the inputs are joined along a newly created axis (optionally specified with the `newaxis` keyword argument).  The `method` keyword argument can be used to specify the join type:

`:inner` - keep only those array values at axis values common to all AxisArrays to be joined
`:left` - keep only those array values at axis values present in the first AxisArray passed
`:right` - keep only those array values at axis values present in the last AxisArray passed
`:outer` (default) - keep all array values: create an AxisArray spanning all of the input axis values

If an array value in the output array is not defined in any of the input arrays (i.e. in the case of a left, right, or outer join), it takes the value of the optional `fillvalue` keyword argument (default zero).
"""
function Base.join(As::AxisArray{T,N,D,Ax}...; fillvalue::T=zero(T),
                   newaxis::Axis=_default_axis(1:length(As), ndims(As[1])+1),
                   method::Symbol=:outer) where {T,N,D,Ax}

    prejoin_resultaxes = map(as -> axismerge(method, as...), map(tuple, axes.(As)...))

    resultaxes = (prejoin_resultaxes..., newaxis)
    resultdata = fill(fillvalue, length.(resultaxes)...)
    result = AxisArray(resultdata, resultaxes...)

    for (i, A) in enumerate(As)
        before_idxs, after_idxs = indexmappings(A.axes, prejoin_resultaxes)
        result.data[(after_idxs..., i)...] = A.data[before_idxs...]
    end #for

    return result

end #join

function _collapse_array_axes(array_name, array_axes...)
    ((array_name, (idx isa Tuple ? idx : (idx,))...) for idx in Iterators.product((Ax.val for Ax in array_axes)...))
end

function _collapse_axes(array_names, array_axes)
    collect(Iterators.flatten(map(array_names, array_axes) do tup_name, tup_array_axes
        _collapse_array_axes(tup_name, tup_array_axes...)
    end))
end

function _splitall(::Val{N}, As...) where N
    tuple((Base.IteratorsMD.split(A, Val(N)) for A in As)...)
end

function _reshapeall(::Val{N}, As...) where N
    tuple((reshape(A, Val(N)) for A in As)...)
end

function _check_common_axes(common_axis_tuple)
    if !all(axisname(first(common_axis_tuple)) .=== axisname.(common_axis_tuple[2:end]))
        throw(ArgumentError("Leading common axes must have the same name in each array"))
    end

    return nothing
end

function _collapsed_axis_eltype(LType, trailing_axes)
    eltypes = map(trailing_axes) do array_trailing_axes
        Tuple{LType, eltype.(array_trailing_axes)...}
    end

    return typejoin(eltypes...)
end

function collapse(::Val{N}, As::Vararg{AxisArray, AN}) where {N, AN}
    collapse(Val(N), ntuple(identity, AN), As...)
end

function collapse(::Val{N}, ::Type{NewArrayType}, As::Vararg{AxisArray, AN}) where {N, AN, NewArrayType<:AbstractArray}
    collapse(Val(N), NewArrayType, ntuple(identity, AN), As...)
end

@generated function collapse(::Val{N}, labels::NTuple{AN, LType}, As::Vararg{AxisArray, AN}) where {N, AN, LType}
    collapsed_dim_int = Int(N) + 1
    new_eltype = Base.promote_eltype(As...)

    quote
        collapse(Val(N), Array{$new_eltype, $collapsed_dim_int}, labels, As...)
    end
end

"""
    collapse(::Val{N}, As::AxisArray...) -> AxisArray
    collapse(::Val{N}, labels::Tuple, As::AxisArray...) -> AxisArray
    collapse(::Val{N}, ::Type{NewArrayType}, As::AxisArray...) -> AxisArray
    collapse(::Val{N}, ::Type{NewArrayType}, labels::Tuple, As::AxisArray...) -> AxisArray

Collapses `AxisArray`s with `N` equal leading axes into a single `AxisArray`.
All additional axes in any of the arrays are collapsed into a single additional
axis of type `Axis{:collapsed, CategoricalVector{Tuple}}`.

### Arguments

* `::Val{N}`: the greatest common dimension to share between all input
                    arrays. The remaining axes are collapsed. All `N` axes must be common
                    to each input array, at the same dimension. Values from `0` up to the
                    minimum number of dimensions across all input arrays are allowed.
* `labels::Tuple`: (optional) an index for each array in `As` used as the leading element in
                   the index tuples in the `:collapsed` axis. Defaults to `1:length(As)`.
* `::Type{NewArrayType<:AbstractArray{_, N+1}}`: (optional) the desired underlying array
                                                 type for the returned `AxisArray`.
* `As::AxisArray...`: `AxisArray`s to be collapsed together.

### Examples

```
julia> price_data = AxisArray(rand(10), Axis{:time}(Date(2016,01,01):Day(1):Date(2016,01,10)))
1-dimensional AxisArray{Float64,1,...} with axes:
    :time, 2016-01-01:1 day:2016-01-10
And data, a 10-element Array{Float64,1}:
 0.885014
 0.418562
 0.609344
 0.72221
 0.43656
 0.840304
 0.455337
 0.65954
 0.393801
 0.260207

julia> size_data = AxisArray(rand(10,2), Axis{:time}(Date(2016,01,01):Day(1):Date(2016,01,10)), Axis{:measure}([:area, :volume]))
2-dimensional AxisArray{Float64,2,...} with axes:
    :time, 2016-01-01:1 day:2016-01-10
    :measure, Symbol[:area, :volume]
And data, a 10×2 Array{Float64,2}:
 0.159434     0.456992
 0.344521     0.374623
 0.522077     0.313256
 0.994697     0.320953
 0.95104      0.900526
 0.921854     0.729311
 0.000922581  0.148822
 0.449128     0.761714
 0.650277     0.135061
 0.688773     0.513845

julia> collapsed = collapse(Val(1), (:price, :size), price_data, size_data)
2-dimensional AxisArray{Float64,2,...} with axes:
    :time, 2016-01-01:1 day:2016-01-10
    :collapsed, Tuple{Symbol,Vararg{Symbol,N} where N}[(:price,), (:size, :area), (:size, :volume)]
And data, a 10×3 Array{Float64,2}:
 0.885014  0.159434     0.456992
 0.418562  0.344521     0.374623
 0.609344  0.522077     0.313256
 0.72221   0.994697     0.320953
 0.43656   0.95104      0.900526
 0.840304  0.921854     0.729311
 0.455337  0.000922581  0.148822
 0.65954   0.449128     0.761714
 0.393801  0.650277     0.135061
 0.260207  0.688773     0.513845

julia> collapsed[Axis{:collapsed}(:size)] == size_data
true
```

"""
@generated function collapse(::Val{N},
                             ::Type{NewArrayType},
                             labels::NTuple{AN, LType},
                             As::Vararg{AxisArray, AN}) where {N, AN, LType, NewArrayType<:AbstractArray}
    if N < 0
        throw(ArgumentError("collapse dimension N must be at least 0"))
    end

    if N > minimum(ndims.(As))
        throw(ArgumentError(
            """
            collapse dimension N must not be greater than the maximum number of dimensions
            across all input arrays
            """
        ))
    end

    collapsed_dim = Val(N + 1)
    collapsed_dim_int = Int(N) + 1

    common_axes, trailing_axes = zip(_splitall(Val(N), axisparams.(As)...)...)

    foreach(_check_common_axes, zip(common_axes...))

    new_common_axes = first(common_axes)
    collapsed_axis_eltype = _collapsed_axis_eltype(LType, trailing_axes)
    collapsed_axis_type = CategoricalVector{collapsed_axis_eltype, Vector{collapsed_axis_eltype}}

    new_axes_type = Tuple{new_common_axes..., Axis{:collapsed, collapsed_axis_type}}
    new_eltype = Base.promote_eltype(As...)

    quote
        common_axes, trailing_axes = zip(_splitall(Val(N), axes.(As)...)...)

        for common_axis_tuple in zip(common_axes...)
            if !isempty(common_axis_tuple)
                for common_axis in common_axis_tuple[2:end]
                    if !all(axisvalues(common_axis) .== axisvalues(common_axis_tuple[1]))
                        throw(ArgumentError(
                            """
                            Leading common axes must be identical across
                            all input arrays"""
                        ))
                    end
                end
            end
        end

        array_data = cat(_reshapeall($collapsed_dim, As...)..., dims=$collapsed_dim)

        axis_array_type = AxisArray{
            $new_eltype,
            $collapsed_dim_int,
            $NewArrayType,
            $new_axes_type
        }

        new_axes = (
            first(common_axes)...,
            Axis{:collapsed, $collapsed_axis_type}($collapsed_axis_type(_collapse_axes(labels, trailing_axes))),
        )

        return axis_array_type(array_data, new_axes)
    end
end
