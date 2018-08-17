const Idx = Union{Real,Colon,AbstractArray{Int}}

using Base: ViewIndex, @propagate_inbounds, tail

abstract type Value{T} end

struct TolValue{T} <: Value{T}
    val::T
    tol::T
end

TolValue(x, tol=Base.rtoldefault(typeof(x))*abs(x)) = TolValue(promote(x,tol)...)

struct ExactValue{T} <: Value{T}
    val::T
end

atvalue(x::Number; rtol=Base.rtoldefault(typeof(x)), atol=zero(x)) = TolValue(x, atol+rtol*abs(x))
atvalue(x) = ExactValue(x)

const Values = AbstractArray{<:Value}

# For throwing a BoundsError with a Value index, we need to define the following
# (note that we could inherit them for free, were Value <: Number)
Base.iterate(x::Value, state = false) = state ? nothing : (x, true)

# Values have the indexing trait of their wrapped type
_axistrait_el(::Type{<:Value{T}}) where {T} = _axistrait_el(T)

# How to show Value objects (e.g. in a BoundsError)
Base.show(io::IO, v::TolValue) =
    print(io, string("TolValue(", v.val, ", tol=", v.tol, ")"))
Base.show(io::IO, v::ExactValue) = print(io, string("ExactValue(", v.val, ")"))

# Defer IndexStyle to the wrapped array
Base.IndexStyle(::Type{AxisArray{T,N,D,Ax}}) where {T,N,D,Ax} = IndexStyle(D)

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
# Linear indexing
reaxis(A::AxisArray{<:Any,1}, I::AbstractArray{Int}) = _new_axes(A.axes[1], I)
reaxis(A::AxisArray, I::AbstractArray{Int}) = default_axes(I)
reaxis(A::AxisArray{<:Any,1}, I::Real) = ()
reaxis(A::AxisArray, I::Real) = ()
reaxis(A::AxisArray{<:Any,1}, I::Colon) = _new_axes(A.axes[1], Base.axes(A, 1))
reaxis(A::AxisArray, I::Colon) = default_axes(Base.OneTo(length(A)))
reaxis(A::AxisArray{<:Any,1}, I::AbstractArray{Bool}) = _new_axes(A.axes[1], findall(I))
reaxis(A::AxisArray, I::AbstractArray{Bool}) = default_axes(findall(I))

# Ensure the number of axes matches the number of indexing dimensions
@inline function make_axes_match(axs, idxs)
    nidxs = Base.index_ndims(idxs...)
    ntuple(i->(Base.@_inline_meta; _default_axis(i > length(axs) ? Base.OneTo(1) : axs[i], i)), length(nidxs))
end

# Now we can reaxis without worrying about mismatched axes/indices
@inline _reaxis(axs::Tuple{}, idxs::Tuple{}) = ()
# Scalars are dropped
const ScalarIndex = Union{Real, AbstractArray{<:Any, 0}}
@inline _reaxis(axs::Tuple, idxs::Tuple{ScalarIndex, Vararg{Any}}) = _reaxis(tail(axs), tail(idxs))
# Colon passes straight through
@inline _reaxis(axs::Tuple, idxs::Tuple{Colon, Vararg{Any}}) = (axs[1], _reaxis(tail(axs), tail(idxs))...)
# But arrays can add or change dimensions and accompanying axis names
@inline _reaxis(axs::Tuple, idxs::Tuple{AbstractArray, Vararg{Any}}) =
    (_new_axes(axs[1], idxs[1])..., _reaxis(tail(axs), tail(idxs))...)

# Vectors simply create new axes with the same name; just subsetted by their value
@inline _new_axes(ax::Axis{name}, idx::AbstractVector) where {name} = (Axis{name}(ax.val[idx]),)
# Arrays create multiple axes with _N appended to the axis name containing their indices
@generated function _new_axes(ax::Axis{name}, idx::AbstractArray{<:Any,N}) where {name,N}
    newaxes = Expr(:tuple)
    for i=1:N
        push!(newaxes.args, :($(Axis{Symbol(name, "_", i)})(Base.axes(idx, $i))))
    end
    newaxes
end
# And indexing with an AxisArray joins the name and overrides the values
@generated function _new_axes(ax::Axis{name}, idx::AxisArray{<:Any, N}) where {name,N}
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
using Base: AbstractCartesianIndex
@propagate_inbounds Base.view(A::AxisArray, idxs::Idx...) = AxisArray(view(A.data, idxs...), reaxis(A, idxs...))

# Setindex is so much simpler. Just assign it to the data:
@propagate_inbounds Base.setindex!(A::AxisArray, v, idxs::Idx...) = (A.data[idxs...] = v)

# Logical indexing
@propagate_inbounds function Base.getindex(A::AxisArray, idx::AbstractArray{Bool})
    AxisArray(A.data[idx], reaxis(A, idx))
end
@propagate_inbounds Base.setindex!(A::AxisArray, v, idx::AbstractArray{Bool}) = (A.data[idx] = v)

### Fancier indexing capabilities provided only by AxisArrays ###
@propagate_inbounds Base.getindex(A::AxisArray, idxs...) = A[to_index(A,idxs...)...]
@propagate_inbounds Base.setindex!(A::AxisArray, v, idxs...) = (A[to_index(A,idxs...)...] = v)
# Deal with lots of ambiguities here
@propagate_inbounds Base.view(A::AxisArray, idxs::ViewIndex...) = view(A, to_index(A,idxs...)...)
@propagate_inbounds Base.view(A::AxisArray, idxs::Union{ViewIndex,AbstractCartesianIndex}...) = view(A, to_index(A,Base.IteratorsMD.flatten(idxs)...)...)
@propagate_inbounds Base.view(A::AxisArray, idxs...) = view(A, to_index(A,idxs...)...)

# First is indexing by named axis. We simply sort the axes and re-dispatch.
# When indexing by named axis the shapes of omitted dimensions are preserved
# TODO: should we handle multidimensional Axis indexes? It could be interpreted
#       as adding dimensions in the middle of an AxisArray.
# TODO: should we allow repeated axes? As a union of indices of the duplicates?
@generated function to_index(A::AxisArray{T,N,D,Ax}, I::Axis...) where {T,N,D,Ax}
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

function Base.reshape(A::AxisArray, ::Val{N}) where N
    axN, _ = Base.IteratorsMD.split(axes(A), Val(N))
    AxisArray(reshape(A.data, Val(N)), Base.front(axN))
end

### Indexing along values of the axes ###

# Default axes indexing throws an error
"""
    axisindexes(ax::Axis, axis_idx) -> array_idx
    axisindexes(::Type{<:AxisTrait}, axis_values, axis_idx) -> array_idx

Translate an index into an axis into an index into the underlying array.
Users can add additional indexing behaviours for custom axes or custom indices by adding
methods to this function.

## Examples

Add a method for indexing into an `Axis{name, SortedSet}`:

```julia
AxisArrays.axisindexes(::Type{Categorical}, ax::SortedSet, idx::AbstractVector) = findin(collect(ax), idx)
```

Add a method for indexing into a `Categorical` axis with a `SortedSet`:

```julia
AxisArrays.axisindexes(::Type{Categorical}, ax::AbstractVector, idx::SortedSet) = findin(ax, idx)
```
"""
axisindexes(ax, idx) = axisindexes(axistrait(ax.val), ax.val, idx)
axisindexes(::Type{Unsupported}, ax, idx) = error("elementwise indexing is not supported for axes of type $(typeof(ax))")
axisindexes(t, ax, idx) = error("cannot index $(typeof(ax)) with $(typeof(idx)); expected $(eltype(ax)) axis value or Integer index")

# Dimensional axes may be indexed directly by their elements if Non-Real and unique
# Maybe extend error message to all <: Numbers if Base allows it?
axisindexes(::Type{Dimensional}, ax::AbstractVector, idx::Real) =
    throw(ArgumentError("invalid index: $idx. Use `atvalue` when indexing by value."))
function axisindexes(::Type{Dimensional}, ax::AbstractVector, idx)
    idxs = searchsorted(ax, ClosedInterval(idx,idx))
    length(idxs) > 1 && error("more than one datapoint lies on axis value $idx; use an interval to return all values")
    if length(idxs) == 1
        idxs[1]
    else
        throw(BoundsError(ax, idx))
    end
end
function axisindexes(::Type{Dimensional}, ax::AbstractVector, idx::Axis)
    idxs = searchsorted(ax, idx.val)
    length(idxs) > 1 && error("more than one datapoint lies on axis value $idx; use an interval to return all values")
    if length(idxs) == 1
        idxs[1]
    else
        throw(BoundsError(ax, idx))
    end
end
# Dimensional axes may always be indexed by value if in a Value type wrapper.
function axisindexes(::Type{Dimensional}, ax::AbstractVector, idx::TolValue)
    idxs = searchsorted(ax, ClosedInterval(idx.val,idx.val))
    length(idxs) > 1 && error("more than one datapoint lies on axis value $idx; use an interval to return all values")
    if length(idxs) == 1
        idxs[1]
    else # it's zero
        last(idxs) > 0 && abs(ax[last(idxs)] - idx.val) < idx.tol && return last(idxs)
        first(idxs) <= length(ax) && abs(ax[first(idxs)] - idx.val) < idx.tol && return first(idxs)
        throw(BoundsError(ax, idx))
    end
end
function axisindexes(::Type{Dimensional}, ax::AbstractVector, idx::ExactValue)
    idxs = searchsorted(ax, ClosedInterval(idx.val,idx.val))
    length(idxs) > 1 && error("more than one datapoint lies on axis value $idx; use an interval to return all values")
    if length(idxs) == 1
        idxs[1]
    else # it's zero
        throw(BoundsError(ax, idx))
    end
end

# Dimensional axes may be indexed by intervals to select a range
axisindexes(::Type{Dimensional}, ax::AbstractVector, idx::ClosedInterval) = searchsorted(ax, idx)

# Or repeated intervals, which only work if the axis is a range since otherwise
# there will be a non-constant number of indices in each repetition.
#
# There are a number of challenges here:
#   * This operation adds a dimension to the result; rows represent the interval
#     (or subset) and columns are offsets (or repetition). A RepeatedRangeMatrix
#     represents the resulting matrix of indices very nicely.
#   * We also want the returned matrix to keep track of its axes; the axis
#     subset (ax_sub) is the relative location of the interval with respect to
#     each offset, and the repetitions (ax_rep) is the array of offsets.
#   * We are interested in the resulting *addition* of the interval against the
#     offsets. Either the offsets or the interval may independently be out of
#     bounds prior to this addition. Even worse: the interval may have different
#     units than the axis (e.g., `(Day(-1)..Day(1)) + dates` for a three-day
#     span around dates of interest over a Date axis).
#   * It is possible (and likely!) that neither the interval endpoints nor the
#     offsets fall exactly upon an axis value. Or even worse: the some offsets
#     when added to the interval could span more elements than others (the
#     fencepost problem). As such, we need to be careful about how and when we
#     snap the provided intervals and offsets to exact axis values (and indices).
#
# To avoid the fencepost problems and to define the axes, we convert the
# interval to a UnitRange of relative indices and the array of offsets to an
# array of absolute indices (independently of each other). Exactly how we do so
# must be carefully considered.
#
# Note that this is fundamentally different than indexing by a single interval;
# whereas those intervals are specified in the same units as the elements of the
# axis itself, these intervals are specified in terms of _offsets_. At the same
# time, we want `A[interval] == vec(A[interval + [0]])`. To make these
# computations as similar as possible, we use a phony range of the form
# `step(ax):step(ax):step(ax)` in order to search for the interval.
phony_range(r::AbstractRange) = step(r):step(r):step(r)
phony_range(r::AbstractUnitRange) = step(r):step(r)
phony_range(r::StepRangeLen) = StepRangeLen(r.step, r.step, 1)
function relativewindow(r::AbstractRange, x::ClosedInterval)
    pr = phony_range(r)
    idxs = Extrapolated.searchsorted(pr, x)
    vals = Extrapolated.getindex(pr, idxs)
    return (idxs, vals)
end

axisindexes(::Type{Dimensional}, ax::AbstractVector, idx::RepeatedInterval) = error("repeated intervals might select a varying number of elements for non-range axes; use a repeated Range of indices instead")
function axisindexes(::Type{Dimensional}, ax::AbstractRange, idx::RepeatedInterval)
    idxs, vals = relativewindow(ax, idx.window)
    offsets = [Extrapolated.searchsortednearest(ax, offset) for offset in idx.offsets]
    AxisArray(RepeatedRangeMatrix(idxs, offsets), Axis{:sub}(vals), Axis{:rep}(Extrapolated.getindex(ax, offsets)))
end

# We also have special datatypes to represent intervals about indices
axisindexes(::Type{Dimensional}, ax::AbstractVector, idx::IntervalAtIndex) = searchsorted(ax, idx.window + ax[idx.index])
function axisindexes(::Type{Dimensional}, ax::AbstractRange, idx::IntervalAtIndex)
    idxs, vals = relativewindow(ax, idx.window)
    AxisArray(idxs .+ idx.index, Axis{:sub}(vals))
end
axisindexes(::Type{Dimensional}, ax::AbstractVector, idx::RepeatedIntervalAtIndexes) = error("repeated intervals might select a varying number of elements for non-range axes; use a repeated Range of indices instead")
function axisindexes(::Type{Dimensional}, ax::AbstractRange,
                     idx::RepeatedIntervalAtIndexes)
    idxs, vals = relativewindow(ax, idx.window)
    AxisArray(RepeatedRangeMatrix(idxs, idx.indexes), Axis{:sub}(vals), Axis{:rep}(ax[idx.indexes]))
end

# Categorical axes may be indexed by their elements
function axisindexes(::Type{Categorical}, ax::AbstractVector, idx)
    i = Compat.findfirst(isequal(idx), ax)
    i === nothing && throw(ArgumentError("index $idx not found"))
    i
end
function axisindexes(::Type{Categorical}, ax::AbstractVector, idx::Value)
    val = idx.val
    i = Compat.findfirst(isequal(val), ax)
    i === nothing && throw(ArgumentError("index $val not found"))
    i
end
# Categorical axes may be indexed by a vector of their elements
function axisindexes(::Type{Categorical}, ax::AbstractVector, idx::AbstractVector)
    res = findall(in(idx), ax)
    length(res) == length(idx) || throw(ArgumentError("index $(setdiff(idx,ax)) not found"))
    res
end

# This catch-all method attempts to convert any axis-specific non-standard
# indexing types to their integer or integer range equivalents using axisindexes
# It is separate from the `Base.getindex` function to allow reuse between
# set- and get- index.
@generated function to_index(A::AxisArray{T,N,D,Ax}, I...) where {T,N,D,Ax}
    ex = Expr(:tuple)
    n = 0
    for i=1:length(I)
        if axistrait(I[i]) <: Categorical && i <= length(Ax.parameters)
            if I[i] <: Axis
                push!(ex.args, :(axisindexes(A.axes[$i], I[$i].val)))
            else
                push!(ex.args, :(axisindexes(A.axes[$i], I[$i])))
            end
            n += 1

            continue
        end

        if I[i] <: Idx
            push!(ex.args, :(I[$i]))
            n += 1
        elseif I[i] <: AbstractArray{Bool}
            push!(ex.args, :(findall(I[$i])))
            n += 1
        elseif I[i] <: Values
            push!(ex.args, :(axisindexes.(Ref(A.axes[$i]), I[$i])))
            n += 1
        elseif I[i] <: CartesianIndex
            for j = 1:length(I[i])
                push!(ex.args, :(I[$i][$j]))
            end
            n += length(I[i])
        elseif i <= length(Ax.parameters)
            if I[i] <: Axis
                push!(ex.args, :(axisindexes(A.axes[$i], I[$i].val)))
            else
                push!(ex.args, :(axisindexes(A.axes[$i], I[$i])))
            end
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
@inline Base.getindex(A::AxisArray, ::Type{Ax}) where {Ax<:Axis} = getaxis(Ax, axes(A)...)
@inline getaxis(::Type{Ax}, ax::Ax, axs...) where {Ax<:Axis} = ax
@inline getaxis(::Type{Ax}, ax::Axis, axs...) where {Ax<:Axis} = getaxis(Ax, axs...)
@noinline getaxis(::Type{Ax}) where {Ax<:Axis} = throw(ArgumentError("no axis of type $Ax was found"))

# Boundschecking specialization: defer to the data array.
# Note that we could unwrap AxisArrays when they are used as indices into other
# arrays within Base's to_index/to_indices methods, but that requires a bigger
# refactor to merge our to_index method with Base's.
@inline Base.checkindex(::Type{Bool}, inds::AbstractUnitRange, A::AxisArray) = Base.checkindex(Bool, inds, A.data)
