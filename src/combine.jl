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

combineaxes{T,N,D,Ax}(As::AxisArray{T,N,D,Ax}...) = combineaxes(:outer, As...)

function combineaxes{T,N,D,Ax}(method::Symbol, As::AxisArray{T,N,D,Ax}...)
    axisnamesvalues = zip(axisnames(As[1]), zip(map(axisvalues, As)...)) |> collect

    resultaxes = Array{Axis}(N)
    resultaxeslengths = Array{Int}(N)
    axismaps = Array{NTuple{2,NTuple{2,Vector{Int64}}}}(N)

    for i in 1:N
        name, valueslists = axisnamesvalues[i]
        mergedaxisvalues = mergevalues(valueslists, method)
        isa(axistrait(mergedaxisvalues), Dimensional) && sort!(mergedaxisvalues)
        resultaxes[i] = Axis{name}(mergedaxisvalues)
        resultaxeslengths[i] = length(mergedaxisvalues)
        axismaps[i] = map(valueslists) do vals
            keepers = intersect(vals, mergedaxisvalues)
            return findin(vals, keepers), findin(mergedaxisvalues, keepers)
        end #do
    end

    axismaps = map(zip(axismaps...)) do mps
        map(idxs->collect(product(idxs...)), zip(mps...))
    end #do

    return resultaxes, resultaxeslengths, axismaps
end #combineaxes

function mergevalues{T}(values::Tuple{Vararg{AbstractVector{T}}}, method::Symbol)
    if method == :inner
        intersect(values...)
    elseif method == :left
        values[1]
    elseif method == :right
        values[end]
    elseif method == :outer
        vcat(values...) |> unique
    else
        error("Join method must be one of :inner, :left, :right, :outer")
    end #if
end

"""
    merge(As::AxisArray...)

Combines AxisArrays with matching axis names into a single AxisArray spanning all of the axis values of the inputs. If a coordinate is defined in more than ones of the inputs, it takes its value from last input in which it appears. If a coordinate in the output array is not defined in any of the input arrays, it takes the value of the optional `fillvalue` keyword argument (default zero).
"""
function Base.merge{T,N,D,Ax}(As::AxisArray{T,N,D,Ax}...; fillvalue::T=zero(T))

    resultaxes, resultaxeslengths, indexmaps = combineaxes(As...)
    result = AxisArray(fill(fillvalue, resultaxeslengths...), resultaxes...)

    for i in 1:length(As)
        A = As[i]
        Aidxs, resultidxs = indexmaps[i]
        for j in eachindex(Aidxs)
            result[resultidxs[j]...] = A[Aidxs[j]...]
        end #for
    end #for

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
function Base.join{T,N,D,Ax}(As::AxisArray{T,N,D,Ax}...; fillvalue::T=zero(T), newaxis::Axis=Axis{_defaultdimname(N+1)}(1:length(As)), method::Symbol=:outer)

    M = length(As)
    resultaxes, resultaxeslengths, indexmaps = combineaxes(method, As...)
    push!(resultaxes, newaxis)
    push!(resultaxeslengths, M)
    result = AxisArray(fill(fillvalue, resultaxeslengths...), resultaxes...)

    for i in 1:M
        A = As[i]
        Aidxs, resultidxs = indexmaps[i]
        for j in eachindex(Aidxs)
            result[[resultidxs[j]...; i]...] = A[Aidxs[j]...]
        end #for
    end #for

    return result

end #join
