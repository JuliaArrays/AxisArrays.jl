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

sizes{T<:AxisArray}(As::T...) = tuple(zip(map(a -> map(length, indices(a)), As)...)...)
matchingdims{N,T<:AxisArray}(As::NTuple{N,T}) = all(equalvalued, sizes(As...))
matchingdimsexcept{N,T<:AxisArray}(As::NTuple{N,T}, n::Int) = all(equalvalued, sizes(As...)[[1:n-1; n+1:end]])

function Base.cat{T}(n::Integer, As::AxisArray{T}...)
    if n <= ndims(As[1])
        matchingdimsexcept(As, n) || error("All non-concatenated axes must be identically-valued")
        newaxis = Axis{axisnames(As[1])[n]}(vcat(map(A -> A.axes[n].val, As)...))
        checkaxis(newaxis)
        return AxisArray(cat(n, map(A->A.data, As)...), (As[1].axes[1:n-1]..., newaxis, As[1].axes[n+1:end]...))
    else
        matchingdims(As) || error("All axes must be identically-valued")
        return AxisArray(cat(n, map(A->A.data, As)...), As[1].axes)
    end #if
end #Base.cat

function axismerge{name,T}(method::Symbol, axes::Axis{name,T}...)

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

function indexmappings{N}(oldaxes::NTuple{N,Axis}, newaxes::NTuple{N,Axis})
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
function Base.merge{T,N,D,Ax}(As::AxisArray{T,N,D,Ax}...; fillvalue::T=zero(T))

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
function Base.join{T,N,D,Ax}(As::AxisArray{T,N,D,Ax}...; fillvalue::T=zero(T),
                             newaxis::Axis=_nextaxistype(As[1].axes)(1:length(As)),
                             method::Symbol=:outer)

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
