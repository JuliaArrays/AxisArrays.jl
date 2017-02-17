typealias Idx Union{Real,Colon,AbstractArray{Int}}

using Base: ViewIndex, linearindexing, unsafe_getindex, unsafe_setindex!

# Defer linearindexing to the wrapped array
Base.linearindexing{T,N,D}(::AxisArray{T,N,D}) = linearindexing(D)

# Cartesian iteration
Base.eachindex(A::AxisArray) = eachindex(A.data)

@generated function reaxis(A::AxisArray, I::Idx...)
    N = length(I)
    # Determine the new axes:
    # Drop linear indexing over multiple axes
    droplastaxis = ndims(A) > N && !(I[end] <: Real) ? 1 : 0
    # Drop trailing scalar dimensions
    lastnonscalar = N
    while lastnonscalar > 0 && I[lastnonscalar] <: Real
        lastnonscalar -= 1
    end
    names = axisnames(A)
    newaxes = Expr[]
    for d=1:lastnonscalar-droplastaxis
        if I[d] <: AxisArray
            # Indexing with an AxisArray joins the axis names
            idxnames = axisnames(I[d])
            for i=1:ndims(I[d])
                push!(newaxes, :($(Axis{Symbol(names[d], "_", idxnames[i])})(I[$d].axes[$i].val)))
            end
        elseif I[d] <: Real
        elseif I[d] <: Union{AbstractVector,Colon}
            push!(newaxes, :($(Axis{names[d]})(A.axes[$d].val[Base.to_index(I[$d])])))
        elseif I[d] <: AbstractArray
            for i=1:ndims(I[d])
                # When we index with non-vector arrays, we *add* dimensions.
                push!(newaxes, :($(Axis{Symbol(names[d], "_", i)})(indices(I[$d], $i))))
            end
        end
    end
    quote
        ($(newaxes...),)
    end
end

@inline function Base.getindex(A::AxisArray, I...)
    J = to_indices(A, I)
    @boundscheck checkbounds(A, J...)
    _getindex(A, J...)
end
# Simple scalar indexing where we just return scalar elements
@inline function _getindex(A, idxs::Number...)
    @inbounds r = A.data[idxs...]
    r
end
# Nonscalar indexing returns a re-axis'ed AxisArray
@inline function _getindex(A, J::Union{Number,AbstractArray}...)
    @inbounds r = AxisArray(A.data[J...], reaxis(A, J...))
    r
end
# Views maintain Axes by wrapping views
@inline function Base.view(A::AxisArray, I...)
    J = to_indices(A, I)
    @boundscheck checkbounds(A, J...)
    @inbounds r = AxisArray(view(A.data, J...), reaxis(A, J...))
    r
end

@inline function Base.setindex!(A::AxisArray, v, I...)
    J = to_indices(A, I)
    @boundscheck checkbounds(A, I...)
    @inbounds A.data[J...] = v
    A
end

# First is indexing by named axis. We simply sort the axes and re-dispatch.
# When indexing by named axis the shapes of omitted dimensions are preserved
# TODO: should we handle multidimensional Axis indexes? It could be interpreted
#       as adding dimensions in the middle of an AxisArray.
# TODO: should we allow repeated axes? As a union of indices of the duplicates?
@generated function Base.to_indices{T,N,D,Ax}(A::AxisArray{T,N,D,Ax}, I::Tuple{Vararg{Axis}})
    dims = Int[axisdim(A, ax) for ax in I]
    idxs = Expr[:(Colon()) for d = 1:N]
    names = axisnames(A)
    for i=1:length(dims)
        idxs[dims[i]] == :(Colon()) ||
            return :(throw(ArgumentError(string("multiple indices provided ",
                "on axis ", $(string(names[dims[i]]))))))
        idxs[dims[i]] = :(I[$i].val)
    end

    meta = Expr(:meta, :inline)
    return :($meta; to_indices(A, ($(idxs...),)))
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
@inline Base.to_indices(A, inds, I::Tuple{Any, Vararg{Any}}) = (_hack(A, inds, I[1]), to_indices(A, Base._maybetail(inds), tail(I))...)
@inline _hack(A::AxisArray, ax, i) = axisindexes(ax[1], i)
@inline _hack(A::AxisArray, ax::Tuple{}, i) = Base.to_index(A,i)
@inline _hack(A, ax, i) = Base.to_index(A,i)

# Ambiguities...
Base.to_indices(A::AxisArray, I::Tuple{}) = ()
@inline Base.to_indices(A::AxisArray, I::Tuple{Vararg{Union{Integer, CartesianIndex}}}) = to_indices(A, (), I)


## Extracting the full axis (name + values) from the Axis{:name} type
@inline Base.getindex{Ax<:Axis}(A::AxisArray, ::Type{Ax}) = getaxis(Ax, axes(A)...)
@inline getaxis{Ax<:Axis}(::Type{Ax}, ax::Ax, axs...) = ax
@inline getaxis{Ax<:Axis}(::Type{Ax}, ax::Axis, axs...) = getaxis(Ax, axs...)
@noinline getaxis{Ax<:Axis}(::Type{Ax}) = throw(ArgumentError("no axis of type $Ax was found"))
