### Indexing returns either a scalar or a smartly-subindexed AxisArray ###

# Limit indexing to types supported by SubArrays, at least initially
typealias Idx Union{Colon,Int,AbstractArray{Int}}

# Defer linearindexing to the wrapped array
import Base: linearindexing, unsafe_getindex, unsafe_setindex!
Base.linearindexing{T,N,D}(::AxisArray{T,N,D}) = linearindexing(D)

# Simple scalar indexing where we just set or return scalars
Base.getindex(A::AxisArray, idxs::Int...) = A.data[idxs...]
Base.setindex!(A::AxisArray, v, idxs::Int...) = (A.data[idxs...] = v)

# Default to views already
Base.getindex{T}(A::AxisArray{T,1}, idx::Colon) = A

# Cartesian iteration
Base.eachindex(A::AxisArray) = eachindex(A.data)
Base.getindex(A::AxisArray, idx::Base.IteratorsMD.CartesianIndex) = A.data[idx]
Base.setindex!(A::AxisArray, v, idx::Base.IteratorsMD.CartesianIndex) = (A.data[idx] = v)

# More complicated cases where we must create a subindexed AxisArray
# TODO: do we want to be dogmatic about using views? For the data? For the axes?
# TODO: perhaps it would be better to return an entirely lazy SubAxisArray view
@generated function Base.getindex{T,N,D,Ax}(A::AxisArray{T,N,D,Ax}, idxs::Idx...)
    # If the last index is a linear indexing range that may span multiple
    # dimensions in the original AxisArray, we can no longer track those axes.
    droplastaxis = N > length(idxs) && !(idxs[end] <: Real)
    names = axisnames(A)
    axes = Expr(:tuple)
    Isplat = Expr[]
    for i = 1:length(idxs)
        if i == length(idxs) && droplastaxis
            push!(Isplat, :(idxs[end]))
            break
        end
        prepaxis!(axes.args, Isplat, idxs[i], names, i)
    end
    quote
        data = view(A.data, $(Isplat...))
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
axisindexes(t, ax, idx) = error("cannot index $(typeof(ax)) with $(typeof(idx)); expected $(eltype(ax)) axis value or Integer index")

# Dimensional axes may be indexed directy by their elements if Non-Real and unique
# Maybe extend error message to all <: Numbers if Base allows it?
axisindexes{T<:Real}(::Type{Dimensional}, ax::AbstractVector{T}, idx::T) = error("indexing by axis value is not supported for axes with $(eltype(ax)) elements; use an ClosedInterval instead")
function axisindexes(::Type{Dimensional}, ax::AbstractVector, idx)
    idxs = searchsorted(ax, ClosedInterval(idx,idx))
    length(idxs) > 1 && error("more than one datapoint lies on axis value $idx; use an interval to return all values")
    idxs[1]
end

# Dimensional axes may be indexed by intervals to select a range
axisindexes{T}(::Type{Dimensional}, ax::AbstractVector{T}, idx::ClosedInterval) = searchsorted(ax, idx)

# Or repeated intervals, which only work if the axis is a range since otherwise
# there will be a non-constant number of indices in each repetition.
# Two small tricks are used here:
# * Compute the resulting interval axis with unsafe indexing without any offset
#   - Since it's a range, we can do this, and it makes the resulting axis useful
# * Snap the offsets to the nearest datapoint to avoid fencepost problems
# Adds a dimension to the result; rows represent the interval and columns are offsets.
axisindexes(::Type{Dimensional}, ax::AbstractVector, idx::RepeatedInterval) = error("repeated intervals might select a varying number of elements for non-range axes; use a repeated Range of indices instead")
function axisindexes(::Type{Dimensional}, ax::Range, idx::RepeatedInterval)
    n = length(idx.offsets)
    idxs = unsafe_searchsorted(ax, idx.window)
    offsets = [searchsortednearest(ax, idx.offsets[i]) for i=1:n]
    AxisArray(RepeatedRangeMatrix(idxs, offsets), Axis{:sub}(unsafe_getindex(ax, idxs)), Axis{:rep}(ax[offsets]))
end

# We also have special datatypes to represent intervals about indices
axisindexes(::Type{Dimensional}, ax::AbstractVector, idx::IntervalAtIndex) = searchsorted(ax, idx.window + ax[idx.index])
function axisindexes(::Type{Dimensional}, ax::Range, idx::IntervalAtIndex)
    idxs = unsafe_searchsorted(ax, idx.window)
    AxisArray(idxs + idx.index, Axis{:sub}(unsafe_getindex(ax, idxs)))
end
axisindexes(::Type{Dimensional}, ax::AbstractVector, idx::RepeatedIntervalAtIndexes) = error("repeated intervals might select a varying number of elements for non-range axes; use a repeated Range of indices instead")
function axisindexes(::Type{Dimensional}, ax::Range, idx::RepeatedIntervalAtIndexes)
    n = length(idx.indexes)
    idxs = unsafe_searchsorted(ax, idx.window)
    AxisArray(RepeatedRangeMatrix(idxs, idx.indexes), Axis{:sub}(unsafe_getindex(ax, idxs)), Axis{:rep}(ax[idx.indexes]))
end

# Categorical axes may be indexed by their elements
function axisindexes(::Type{Categorical}, ax::AbstractVector, idx)
    i = findfirst(ax, idx)
    i == 0 && throw(ArgumentError("index $idx not found"))
    i
end
# Categorical axes may be indexed by a vector of their elements
function axisindexes(::Type{Categorical}, ax::AbstractVector, idx::AbstractVector)
    res = findin(ax, idx)
    length(res) == length(idx) || throw(ArgumentError("index $(setdiff(idx,ax)) not found"))
    res
end

# This catch-all method attempts to convert any axis-specific non-standard
# indexing types to their integer or integer range equivalents using axisindexes
# It is separate from the `Base.getindex` function to allow reuse between
# set- and get- index.
@inline to_index{T,N,D,Ax}(A::AxisArray{T,N,D,Ax}, I...) = _to_index(A, (), I...)
@inline _to_index{T,N}(A::AxisArray{T,N}, tup::NTuple{N}) = tup
@inline _to_index{T,N}(A::AxisArray{T,N}, tup) = Base.fill_to_length(tup, :, Val{N})
@inline _to_index(A, tup, i::Idx, I...) = _to_index(A, (tup..., i), I...)
@inline _to_index(A, tup, i::AbstractArray{Bool}, I...) = _to_index(A, (tup..., find(i)), I...)
@inline _to_index(A, tup, i, I...) = _to_index(A, (tup..., axisindexes(A.axes[length(tup)+1], i)), I...)

function prepaxis!{I<:Union{AbstractVector,Colon}}(axesargs, Isplat, ::Type{I}, names, i)
    idx = :(idxs[$i])
    push!(axesargs, :($(Axis{names[i]})(A.axes[$i].val[$idx])))
    push!(Isplat, :(idxs[$i]))
    axesargs, Isplat
end
function prepaxis!{I<:AxisArray}(axesargs, Isplat, ::Type{I}, names, i)
    idxnames = axisnames(I)
    for j=1:ndims(I)
        push!(axesargs, :($(Axis{Symbol(names[i], "_", idxnames[j])})(idxs[$i].axes[$j].val)))
    end
    push!(Isplat, :(idxs[$i]))
    axesargs, Isplat
end
function prepaxis!{I<:AbstractArray}(axesargs, Isplat, ::Type{I}, names, i)
    idxnames = axisnames(I)
    for j=1:ndims(I)
        push!(axesargs, :($(Axis{Symbol(names[i], "_", j)})(1:size(I[$d], $i))))
    end
    push!(Isplat, :(idxs[$i]))
    axesargs, Isplat
end
# For anything scalar-like
function prepaxis!{I}(axesargs, Isplat, ::Type{I}, names, i)
    push!(Isplat, :(idxs[$i]))
    axesargs, Isplat
end
