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

sizes{T<:AxisArray}(As::T...) = tuple(zip(map(size, As)...)...)
matchingdims{N,T<:AxisArray}(As::NTuple{N,T}) = all(equalvalued, sizes(As...))
matchingdimsexcept{N,T<:AxisArray}(As::NTuple{N,T}, n::Int) = all(equalvalued, sizes(As[[1:n-1; n+1:end]]...))

function Base.cat{T<:AxisArray}(n::Int, As::T...)
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

function Base.merge{T}(As::AxisArray{T}...)

    resultaxes = Axis[]
    resultaxeslengths = Int[]
    axismappings = Any[] #TODO: More precise typing

    for (name, values) in zip(axisnames(As[1]), zip(map(axisvalues, As)...))
        mergedaxisvalues = vcat(values...) |> unique
        isa(axistrait(mergedaxisvalues), Dimensional) && sort!(mergedaxisvalues)
        push!(axismappings, map(vals->findin(mergedaxisvalues, vals), values))
        push!(resultaxes, Axis{name}(mergedaxisvalues))
        push!(resultaxeslengths, length(mergedaxisvalues))
    end

    axismappings = collect(zip(axismappings...))
    result = AxisArray(zeros(T, resultaxeslengths...), resultaxes...)

    for i in eachindex(collect(As))
        A, mapping = As[i], axismappings[i]
        for ci in product(map(n->1:n, size(A))...)
            mappedci = [mapping[d][ci[d]] for d in eachindex(collect(ci))]
            result[mappedci...] = A[ci...]
        end #for
    end #for

    return result

end #merge

