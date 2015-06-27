### Indexing returns either a scalar or a smartly-subindexed AxisArray ###

# Limit indexing to types supported by SubArrays, at least initially
typealias Idx Union(Colon,Int,Array{Int,1},Range{Int})

# Defer linearindexing to the wrapped array
import Base: linearindexing
Base.linearindexing{T,N,D}(::AxisArray{T,N,D}) = linearindexing(D)

# Simple scalar indexing where we just set or return scalars
Base.getindex(A::AxisArray, idxs::Int...) = A.data[idxs...]
Base.setindex!(A::AxisArray, v, idxs::Int...) = (A.data[idxs...] = v)

# Linear indexing with an array. TODO: Make getindex return an AxisArray
Base.getindex(A::AxisArray, idx::AbstractArray{Int}) = A.data[idx]
Base.setindex!(A::AxisArray, v, idx::AbstractArray{Int}) = (A.data[idx] = v)

# Default to views already
Base.getindex{T}(A::AxisArray{T,1}, idx::Colon) = A

# Cartesian iteration
Base.eachindex(A::AxisArray) = eachindex(A.data)
Base.getindex(A::AxisArray, idx::Base.IteratorsMD.CartesianIndex) = A.data[idx]
Base.setindex!(A::AxisArray, v, idx::Base.IteratorsMD.CartesianIndex) = (A.data[idx] = v)

# More complicated cases where we must create a subindexed AxisArray
# TODO: do we want to be dogmatic about using views? For the data? For the axes?
# TODO: perhaps it would be better to return an entirely lazy SubAxisArray view
@generated function Base.getindex{T,N,D,Ax}(A::AxisArray{T,N,D,Ax}, idxs::Union(Idx,AxisArray)...)
    newdims = length(idxs)
    # If the last index is a linear indexing range that may span multiple
    # dimensions in the original AxisArray, we can no longer track those axes.
    droplastaxis = N > newdims && !(idxs[end] <: Real) ? 1 : 0
    # Drop trailing scalar dimensions
    while newdims > 0 && idxs[newdims] <: Real
        newdims -= 1
    end
    names = axisnames(A)
    axes = Expr(:tuple)
    for i = 1:newdims-droplastaxis
        if idxs[i] <: Real
            idx = :(idxs[$i]:idxs[$i])
        elseif idxs[i] <: Vector{UnitRange{Int}}
            # Indexing by a vector of unitranges *adds* a dimension...
        idx = idxs[i] <: Real ? ( : (:(idxs[$i]))
        push!(axes.args, :($(Axis{names[i]})(A.axes[$i].val[$idx])))
    end
    Isplat = Expr[:(idxs[$d]) for d=1:length(idxs)]
    quote
        data = sub(A.data, $(Isplat...))
        AxisArray(data, $axes) # TODO: avoid checking the axes here
    end
end
# Setindex is so much simpler. Just assign it to the data:
Base.setindex!(A::AxisArray, v, idxs::Idx...) = (A.data[idxs...] = v)

### Fancier indexing capabilities provided only by AxisArrays ###
Base.getindex(A::AxisArray, idxs...) = A[to_index(A,idxs...)...]
Base.setindex!(A::AxisArray, v, idxs...) = (A[to_index(A,idxs...)...] = v)

# First is indexing by named axis. We simply sort the axes and re-dispatch.
# When indexing by named axis the shapes of omitted dimensions are preserved
# TODO: should we handle multidimensional Axis indexes? It could be interpreted
#       as adding dimensions in the middle of an AxisArray.
# TODO: should we allow repeated axes? As a union of indices of the duplicates?
@generated function to_index{T,N,D,Ax}(A::AxisArray{T,N,D,Ax}, I::Axis...)
    dims = Int[axisdim(A, ax) for ax in I]
    idxs = Expr[:(Colon()) for d = 1:N]
    names = axisnames(A)
    for i=1:length(dims)
        idxs[dims[i]] == :(Colon()) || return :(error("multiple indices provided on axis ", $(names[dims[i]])))
        idxs[dims[i]] = :(I[$i].val)
    end

    meta = Expr(:meta, :inline)
    return :($meta; to_index(A, $(idxs...)))
end

### Indexing along values of the axes ###

# Default axes indexing throws an error
axisindexes(ax, idx) = axisindexes(axistrait(ax.val), ax.val, idx)
axisindexes(::Type{Unsupported}, ax, idx) = error("elementwise indexing is not supported for axes of type $(typeof(ax))")
# Dimensional axes may be indexed by intervals of their elements
axisindexes{T}(::Type{Dimensional}, ax::AbstractVector{T}, idx::Interval{T}) = searchsorted(ax, idx)
# Or an array of intervals of their elements - convert the interval of elements to an interval of idices
axisindexes{T}(::Type{Dimensional}, ax::AbstractVector{T}, I::RepeatedInterval{T,T}) = [searchsorted(ax, idx) for idx in I]
# Dimensional axes may also be indexed directy by their elements
axisindexes{T}(::Type{Dimensional}, ax::AbstractVector{T}, idx::T) = searchsorted(ax, Interval(idx,idx))
# Categorical axes may be indexed by their elements
function axisindexes{T}(::Type{Categorical}, ax::AbstractVector{T}, idx::T)
    i = findfirst(ax, idx)
    i == 0 && throw(ArgumentError("index $idx not found"))
    i
end
# Categorical axes may be indexed by a vector of their elements
function axisindexes{T}(::Type{Categorical}, ax::AbstractVector{T}, idx::AbstractVector{T})
    res = findin(ax, idx)
    length(res) == length(idx) || throw(ArgumentError("index $(setdiff(idx,ax)) not found"))
    res
end

# This catch-all method attempts to convert any axis-specific non-standard
# indexing types to their integer or integer range equivalents using axisindexes
# It is separate from the `Base.getindex` function to allow reuse between
# set- and get- index.
@generated function to_index{T,N,D,Ax}(A::AxisArray{T,N,D,Ax}, I...)
    ex = Expr(:tuple)
    for i=1:length(I)
        if I[i] <: Idx
            push!(ex.args, :(I[$i]))
        elseif i <= Tuples.length(Ax)
            push!(ex.args, :(axisindexes(A.axes[$i], I[$i])))
        else
            push!(ex.args, :(error("dimension ", $i, " does not have an axis to index")))
        end
    end
    for _=length(I)+1:N
        push!(ex.args, :(Colon()))
    end
    meta = Expr(:meta, :inline)
    return :($meta; $ex)
end
