const Idx = Union{Real,Colon,AbstractArray{Int}}

using Base: ViewIndex, @propagate_inbounds, tail

# Defer IndexStyle to the wrapped array
@compat Base.IndexStyle{T,N,D,Ax}(::Type{AxisArray{T,N,D,Ax}}) = IndexStyle(D)

# Simple scalar indexing where we just set or return scalars
@propagate_inbounds Base.getindex(A::AxisArray, idxs::Int...) = A.data[idxs...]
@propagate_inbounds Base.setindex!(A::AxisArray, v, idxs::Int...) = (A.data[idxs...] = v)

# Cartesian iteration
Base.eachindex(A::AxisArray) = eachindex(A.data)

"""
    reaxis(A::AxisArray, I...)

This internal function determines the new set of axes that are constructed upon
indexing with I.
"""
reaxis(A::AxisArray, I::Idx...) = _reaxis(make_axes_match(axes(A), I), I)
# Ensure the number of axes matches the number of indexing dimensions
@inline make_axes_match(axs, idxs) = _make_axes_match((), axs, Base.index_ndims(idxs...))
# Move the axes into newaxes, until we run out of both simultaneously
@inline _make_axes_match(newaxes, axs::Tuple, nidxs::Tuple) =
    _make_axes_match((newaxes..., axs[1]), tail(axs), tail(nidxs))
@inline _make_axes_match(newaxes, axs::Tuple{}, nidxs::Tuple{}) = newaxes
# Drop trailing axes, replacing it with a default name for the linear span
@inline _make_axes_match(newaxes, axs::Tuple, nidxs::Tuple{}) =
    (maybefront(newaxes)..., _nextaxistype(newaxes)(Base.OneTo(length(newaxes[end]) * prod(map(length, axs)))))
# Insert phony singleton trailing axes
@inline _make_axes_match(newaxes, axs::Tuple{}, nidxs::Tuple) =
    _make_axes_match((newaxes..., _nextaxistype(newaxes)(Base.OneTo(1))), (), tail(nidxs))

@inline maybefront(::Tuple{}) = ()
@inline maybefront(t::Tuple) = Base.front(t)

# Now we can reaxis without worrying about mismatched axes/indices
@inline _reaxis(axs::Tuple{}, idxs::Tuple{}) = ()
# Scalars are dropped
const ScalarIndex = @compat Union{Real, AbstractArray{<:Any, 0}}
@inline _reaxis(axs::Tuple, idxs::Tuple{ScalarIndex, Vararg{Any}}) = _reaxis(tail(axs), tail(idxs))
# Colon passes straight through
@inline _reaxis(axs::Tuple, idxs::Tuple{Colon, Vararg{Any}}) = (axs[1], _reaxis(tail(axs), tail(idxs))...)
# But arrays can add or change dimensions and accompanying axis names
@inline _reaxis(axs::Tuple, idxs::Tuple{AbstractArray, Vararg{Any}}) =
    (_new_axes(axs[1], idxs[1])..., _reaxis(tail(axs), tail(idxs))...)

# Vectors simply create new axes with the same name; just subsetted by their value
@inline _new_axes{name}(ax::Axis{name}, idx::AbstractVector) = (Axis{name}(ax.val[idx]),)
# Arrays create multiple axes with _N appended to the axis name containing their indices
@generated function _new_axes{name, N}(ax::Axis{name}, idx::@compat(AbstractArray{<:Any,N}))
    newaxes = Expr(:tuple)
    for i=1:N
        push!(newaxes.args, :($(Axis{Symbol(name, "_", i)})(indices(idx, $i))))
    end
    newaxes
end
# And indexing with an AxisArray joins the name and overrides the values
@generated function _new_axes{name, N}(ax::Axis{name}, idx::@compat(AxisArray{<:Any, N}))
    newaxes = Expr(:tuple)
    idxnames = axisnames(idx)
    for i=1:N
        push!(newaxes.args, :($(Axis{Symbol(name, "_", idxnames[i])})(idx.axes[$i].val)))
    end
    newaxes
end

@propagate_inbounds function Base.getindex(A::AxisArray, idxs::Idx...)
    AxisArray(A.data[idxs...], reaxis(A, idxs...))
end

# To resolve ambiguities, we need several definitions
if VERSION >= v"0.6.0-dev.672"
    using Base.AbstractCartesianIndex
    @propagate_inbounds Base.view(A::AxisArray, idxs::Idx...) = AxisArray(view(A.data, idxs...), reaxis(A, idxs...))
else
    @propagate_inbounds function Base.view{T,N}(A::AxisArray{T,N}, idxs::Vararg{Idx,N})
        AxisArray(view(A.data, idxs...), reaxis(A, idxs...))
    end
    @propagate_inbounds function Base.view(A::AxisArray, idx::Idx)
        AxisArray(view(A.data, idx), reaxis(A, idx))
    end
    @propagate_inbounds function Base.view{N}(A::AxisArray, idxs::Vararg{Idx,N})
        # this should eventually be deleted, see julia #14770
        AxisArray(view(A.data, idxs...), reaxis(A, idxs...))
    end
end

# Setindex is so much simpler. Just assign it to the data:
@propagate_inbounds Base.setindex!(A::AxisArray, v, idxs::Idx...) = (A.data[idxs...] = v)

### Fancier indexing capabilities provided only by AxisArrays ###
@propagate_inbounds Base.getindex(A::AxisArray, idxs...) = A[to_index(A,idxs...)...]
@propagate_inbounds Base.setindex!(A::AxisArray, v, idxs...) = (A[to_index(A,idxs...)...] = v)
# Deal with lots of ambiguities here
if VERSION >= v"0.6.0-dev.672"
    @propagate_inbounds Base.view(A::AxisArray, idxs::ViewIndex...) = view(A, to_index(A,idxs...)...)
    @propagate_inbounds Base.view(A::AxisArray, idxs::Union{ViewIndex,AbstractCartesianIndex}...) = view(A, to_index(A,Base.IteratorsMD.flatten(idxs)...)...)
    @propagate_inbounds Base.view(A::AxisArray, idxs...) = view(A, to_index(A,idxs...)...)
else
    for T in (:ViewIndex, :Any)
        @eval begin
            @propagate_inbounds function Base.view{T,N}(A::AxisArray{T,N}, idxs::Vararg{$T,N})
                view(A, to_index(A,idxs...)...)
            end
            @propagate_inbounds function Base.view(A::AxisArray, idx::$T)
                view(A, to_index(A,idx)...)
            end
            @propagate_inbounds function Base.view{N}(A::AxisArray, idsx::Vararg{$T,N})
                # this should eventually be deleted, see julia #14770
                view(A, to_index(A,idxs...)...)
            end
        end
    end
end

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
        idxs[dims[i]] == :(Colon()) ||
            return :(throw(ArgumentError(string("multiple indices provided ",
                "on axis ", $(string(names[dims[i]]))))))
        idxs[dims[i]] = :(I[$i].val)
    end

    meta = Expr(:meta, :inline)
    return :($meta; to_index(A, $(idxs...)))
end

function Base.reshape{N}(A::AxisArray, ::Type{Val{N}})
    # axN, _ = Base.IteratorsMD.split(axes(A), Val{N})
    # AxisArray(reshape(A.data, Val{N}), reaxis(A, Base.fill_to_length(axN, :, Val{N})...))
    AxisArray(reshape(A.data, Val{N}), reaxis(A, ntuple(d->Colon(), Val{N})...))
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
    AxisArray(RepeatedRangeMatrix(idxs, offsets), Axis{:sub}(inbounds_getindex(ax, idxs)), Axis{:rep}(ax[offsets]))
end

# We also have special datatypes to represent intervals about indices
axisindexes(::Type{Dimensional}, ax::AbstractVector, idx::IntervalAtIndex) = searchsorted(ax, idx.window + ax[idx.index])
function axisindexes(::Type{Dimensional}, ax::Range, idx::IntervalAtIndex)
    idxs = unsafe_searchsorted(ax, idx.window)
    AxisArray(idxs + idx.index, Axis{:sub}(inbounds_getindex(ax, idxs)))
end
axisindexes(::Type{Dimensional}, ax::AbstractVector, idx::RepeatedIntervalAtIndexes) = error("repeated intervals might select a varying number of elements for non-range axes; use a repeated Range of indices instead")
function axisindexes(::Type{Dimensional}, ax::Range, idx::RepeatedIntervalAtIndexes)
    n = length(idx.indexes)
    idxs = unsafe_searchsorted(ax, idx.window)
    AxisArray(RepeatedRangeMatrix(idxs, idx.indexes), Axis{:sub}(inbounds_getindex(ax, idxs)), Axis{:rep}(ax[idx.indexes]))
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
@generated function to_index{T,N,D,Ax}(A::AxisArray{T,N,D,Ax}, I...)
    ex = Expr(:tuple)
    n = 0
    for i=1:length(I)
        if I[i] <: Idx
            push!(ex.args, :(I[$i]))
            n += 1
        elseif I[i] <: AbstractArray{Bool}
            push!(ex.args, :(find(I[$i])))
            n += 1
        elseif I[i] <: CartesianIndex
            for j = 1:length(I[i])
                push!(ex.args, :(I[$i][$j]))
            end
            n += length(I[i])
        elseif i <= length(Ax.parameters)
            push!(ex.args, :(axisindexes(A.axes[$i], I[$i])))
            n += 1
        else
            push!(ex.args, :(error("dimension ", $i, " does not have an axis to index")))
        end
    end
    for _=n+1:N
        push!(ex.args, :(Colon()))
    end
    meta = Expr(:meta, :inline)
    return :($meta; $ex)
end

## Extracting the full axis (name + values) from the Axis{:name} type
@inline Base.getindex{Ax<:Axis}(A::AxisArray, ::Type{Ax}) = getaxis(Ax, axes(A)...)
@inline getaxis{Ax<:Axis}(::Type{Ax}, ax::Ax, axs...) = ax
@inline getaxis{Ax<:Axis}(::Type{Ax}, ax::Axis, axs...) = getaxis(Ax, axs...)
@noinline getaxis{Ax<:Axis}(::Type{Ax}) = throw(ArgumentError("no axis of type $Ax was found"))

# Boundschecking specialization: defer to the data array.
# Note that we could unwrap AxisArrays when they are used as indices into other
# arrays within Base's to_index/to_indices methods, but that requires a bigger
# refactor to merge our to_index method with Base's.
@inline Base.checkindex(::Type{Bool}, inds::AbstractUnitRange, A::AxisArray) = Base.checkindex(Bool, inds, A.data)
