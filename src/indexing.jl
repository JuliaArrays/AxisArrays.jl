### Indexing returns either a scalar or a smartly-subindexed AxisArray ###

# Limit indexing to types supported by SubArrays, at least initially
typealias Idx Union{Colon,Int,AbstractVector{Int}}

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
    Isplat = Expr[]
    reshape = false
    newshape = Expr[]
    for i = 1:newdims-droplastaxis
        if idxs[i] <: Real
            idx = :(idxs[$i]:idxs[$i])
            push!(axes.args, :($(Axis{names[i]})(A.axes[$i].val[$idx])))
            push!(Isplat, :(idxs[$i]))
        else
            idx = :(idxs[$i])
            push!(axes.args, :($(Axis{names[i]})(A.axes[$i].val[$idx])))
            push!(Isplat, :(idxs[$i]))
        end
    end
    Isplat = Expr[:(idxs[$d]) for d=1:length(idxs)]
    quote
        data = sub(A.data, $(Isplat...))
        AxisArray(data, $axes) # TODO: avoid checking the axes here
    end
end

# When we index with non-vector arrays, we *add* dimensions. This isn't
# supported by SubArray currently, so we instead return a copy.
# TODO: we probably shouldn't hack Base like this, but it's so convenient...
@inline Base.index_shape_dim(A, dim, i::AbstractArray{Bool}, I...) = (sum(i), Base.index_shape_dim(A, dim+1, I...)...)
@inline Base.index_shape_dim(A, dim, i::AbstractArray, I...) = (size(i)..., Base.index_shape_dim(A, dim+1, I...)...)
@generated function Base.getindex(A::AxisArray, I::Union{Idx, AbstractArray{Int}}...)
    N = length(I)
    Isplat = [:(I[$d]) for d=1:N]
    # Determine the new axes:
    # Like above, drop linear indexing over multiple axes
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
            idxnames = axisnames(I[d])
            for i=1:ndims(I[d])
                push!(newaxes, :($(Axis{symbol(names[d], "_", idxnames[i])})(I[$d].axes[$i].val)))
            end
        elseif I[d] <: Idx
            push!(newaxes, :($(Axis{names[d]})(A.axes[$d].val[J[$d]])))
        elseif I[d] <: AbstractArray
            for i=1:ndims(I[d])
                push!(newaxes, :($(Axis{symbol(names[d], "_", i)})(1:size(I[$d], $i))))
            end
        end
    end
    quote
        # First copy the data using scalar indexing - an adaptation of Base
        checkbounds(A, I...)
        J = Base.to_indexes($(Isplat...))
        sz = Base.index_shape(A, J...)
        idx_lens = Base.index_lengths(A, J...)
        src = A.data
        dest = similar(A.data, sz)
        D = eachindex(dest)
        Ds = start(D)
        Base.Cartesian.@nloops $N i d->(1:idx_lens[d]) d->(j_d = unsafe_getindex(J[d], i_d)) begin
            d, Ds = next(D, Ds)
            v = Base.Cartesian.@ncall $N unsafe_getindex src j
            unsafe_setindex!(dest, v, d)
        end
        # And now create the AxisArray:
        AxisArray(dest, $(newaxes...))
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
axisindexes(t, ax, idx) = error("cannot index $(typeof(ax)) with $(typeof(idx)); expected $(eltype(ax)) or Int")

# Dimensional axes may be indexed directy by their elements
axisindexes{T}(::Type{Dimensional}, ax::AbstractVector{T}, idx::T) = searchsorted(ax, Interval(idx,idx))

# Dimensional axes may be indexed by intervals of their elements to select a range
axisindexes{T}(::Type{Dimensional}, ax::AbstractVector{T}, idx::Interval{T}) = searchsorted(ax, idx)
# Or intervals of Ints, which are equivalent to a index range
axisindexes(::Type{Dimensional}, ax::AbstractVector, idx::Interval{Int}) = minimum(idx):maximum(idx)

# Or offset intervals, which shift the resulting axes of the indexing operation
# to either an axis of integer offsets or the possibly-extrapolated range
new_interval_axis(::AbstractVector, idxs) = idxs # TODO: This creates an integer axis, which isn't indexable by value
new_interval_axis(r::Range, idxs) = unsafe_getindex(r, idxs)
"Return the index of the element in the sorted vector `vec` whose value is closest to `x`"
function searchsortednearest{T}(vec::AbstractVector{T}, x)
    idx = searchsortedfirst(vec, x) # Returns the first idx | vec[idx] >= x
    if idx > 1 && (vec[idx] - x) > (x - vec[idx-1])
        idx -= 1 # The previous element is closer
    end
    return idx
end
# TODO: This could plug into the sorting system better, but it's fine for now
# STOLEN FROM BASE, with the bounds-correcting min/max removed
# TODO: This needs to support Dates.
function unsafe_searchsortedlast{T<:Number}(a::Range{T}, x::Number)
    if step(a) == 0
        isless(x, first(a)) ? 0 : length(a)
    else
        n = round(Integer,(x-first(a))/step(a))+1
        isless(x, unsafe_getindex(a, n)) ? n-1 : n
    end
end
function unsafe_searchsortedfirst{T<:Number}(a::Range{T}, x::Number)
    if step(a) == 0
        isless(first(a), x) ? length(a)+1 : 1
    else
        n = round(Integer,(x-first(a))/step(a))+1
        isless(unsafe_getindex(a, n), x) ? n+1 : n
    end
end
function unsafe_searchsortedlast{T<:Integer}(a::Range{T}, x::Number)
    if step(a) == 0
        isless(x, first(a)) ? 0 : length(a)
    else
        fld(floor(Integer,x)-first(a),step(a))+1
    end
end
function unsafe_searchsortedfirst{T<:Integer}(a::Range{T}, x::Number)
    if step(a) == 0
        isless(first(a), x) ? length(a)+1 : 1
    else
        -fld(floor(Integer,-x)+first(a),step(a))+1,l
    end
end
function unsafe_searchsortedfirst{T<:Integer}(a::Range{T}, x::Unsigned)
    if step(a) == 0
        isless(first(a), x) ? length(a)+1 : 1
    else
        -fld(first(a)-signed(x),step(a))+1,l
    end
end
function unsafe_searchsortedlast{T<:Integer}(a::Range{T}, x::Unsigned)
    if step(a) == 0
        isless(x, first(a)) ? 0 : length(a)
    else
        fld(signed(x)-first(a),step(a))+1
    end
end
"Return the indices within an interval, possibly extrapolating if needed"
function unsafe_searchsorted(a::Range, I::Interval)
    unsafe_searchsortedfirst(a, I.lo):unsafe_searchsortedlast(a, I.hi)
end
# Dispatch is a little tricky with ambiguities, so we use inner functions
axisindexes{T}(::Type{Dimensional}, ax::AbstractVector{T}, idx::OffsetInterval{T,T}) = _tt(ax, idx)
# Order of operations is tricky.  We want to be careful to always *snap* to the
# nearest offset first, and then compute the interval about that offset.
function _tt{T}(ax::AbstractVector{T}, idx::OffsetInterval{T,T})
    loc = searchsortednearest(ax, idx.offset)
    idxs = searchsorted(ax, idx.window + ax[loc])
    AxisArray(idxs, Axis{:sub}(new_interval_axis(ax, idxs - loc)))
end
# And for ranges, we want to pre-compute the theoretical range to ensure that
# there are always the same number of elements at every offset
function _tt{T}(ax::Range{T}, idx::OffsetInterval{T,T})
    idxs = unsafe_searchsorted(ax, idx.window)
    AxisArray(idxs + searchsortednearest(ax, idx.offset), Axis{:sub}(new_interval_axis(ax, idxs)))
end
axisindexes(::Type{Dimensional}, ax::AbstractVector{Int}, idx::OffsetInterval{Int,Int}) = _ii(ax, idx) # Just to avoid ambiguity
axisindexes(::Type{Dimensional}, ax::AbstractVector, idx::OffsetInterval{Int,Int}) = _ii(ax, idx)
function _ii(ax::AbstractVector{Int}, idx::OffsetInterval{Int,Int})
    idxs = minimum(idx.window):maximum(idx.window)
    AxisArray(idxs + idx.offset, Axis{:sub}(new_interval_axis(ax, idxs)))
end
axisindexes{T}(::Type{Dimensional}, ax::AbstractVector{T}, idx::OffsetInterval{T,Int}) = _ti(ax, idx)
function _ti{T}(ax::AbstractVector{T}, idx::OffsetInterval{T,Int})
    idxs = searchsorted(ax, idx.window + ax[idx.offset])
    AxisArray(idxs, Axis{:sub}(new_interval_axis(ax, idxs - idx.offset)))
end
function _ti{T}(ax::Range{T}, idx::OffsetInterval{T,Int})
    idxs = unsafe_searchsorted(ax, idx.window)
    AxisArray(idxs + idx.offset, Axis{:sub}(new_interval_axis(ax, idxs - idx.offset)))
end
function axisindexes{T}(::Type{Dimensional}, ax::AbstractVector{T}, idx::OffsetInterval{Int,T})
    idxs = minimum(idx.window):maximum(idx.window)
    AxisArray(idxs + searchsortednearest(ax, idx.offset), Axis{:sub}(new_interval_axis(ax, idxs)))
end

# Or a repeated offset intarval - convert to a Matrix of indices
axisindexes{T}(::Type{Dimensional}, ax::AbstractVector{T}, idx::RepeatedInterval{T,T}) = _rtt(ax, idx)
_rtt{T}(ax::AbstractVector{T}, idx::RepeatedInterval{T,T}) = error("intervals specified in axis values may specify a varying number of elements for non-range axes. Use an interval of `Int` instead.")
# For ranges, we want to pre-compute the theoretical range to ensure that there
# are always the same number of elements at every offset (without numerical
# instability)
function _rtt{T}(ax::Range{T}, idx::RepeatedInterval{T,T})
    n = length(idx.offsets)
    V = Vector{UnitRange{Int}}(n)
    idxs = unsafe_searchsorted(ax, idx.window)
    offsets = Vector{Int}(n)
    for i=1:n
        offsets[i] = searchsortednearest(ax, idx.offsets[i])
        V[i] = idxs + offsets[i]
    end
    AxisArray(RangeMatrix(V), Axis{:sub}(unsafe_getindex(ax, idxs)), Axis{:rep}(ax[offsets]))
end
axisindexes(::Type{Dimensional}, ax::AbstractVector{Int}, idx::RepeatedInterval{Int,Int}) = _rii(ax, idx) # Just to avoid ambiguity
axisindexes(::Type{Dimensional}, ax::AbstractVector, idx::RepeatedInterval{Int,Int}) = _rii(ax, idx)
function _rii(ax::AbstractVector{Int}, idx::OffsetInterval{Int,Int})
    n = length(idx.offsets)
    V = Vector{UnitRange{Int}}(n)
    idxs = minimum(idx.window):maximum(idx.window)
    for i=1:n
        V[i] = idxs + idx.offsets[i]
    end
    AxisArray(RangeMatrix(V), Axis{:sub}(new_interval_axis(ax, idxs)), Axis{:rep}(ax[idx.offsets]))
end
axisindexes{T}(::Type{Dimensional}, ax::AbstractVector{T}, idx::RepeatedInterval{T,Int}) = _rti(ax, idx)
_rti{T}(ax::AbstractVector{T}, idx::RepeatedInterval{T,Int}) = error("intervals specified in axis values may specify a varying number of elements for non-range axes. Use an interval of `Int` instead.")
function _rti{T}(ax::Range{T}, idx::RepeatedInterval{T,Int})
    n = length(idx.offsets)
    V = Vector{UnitRange{Int}}(n)
    idxs = unsafe_searchsorted(ax, idx.window)
    for i=1:n
        V[i] = idxs + idx.offsets[i]
    end
    AxisArray(RangeMatrix(V), Axis{:sub}(unsafe_getindex(ax, idxs)), Axis{:rep}(ax[idx.offsets]))
end
function axisindexes{T}(::Type{Dimensional}, ax::AbstractVector{T}, idx::RepeatedInterval{Int,T})
    n = length(idx.offsets)
    V = Vector{UnitRange{Int}}(n)
    idxs = minimum(idx.window):maximum(idx.window)
    offsets = Vector{Int}(n)
    for i=1:n
        offsets[i] = searchsortednearest(ax, idx.offsets[i])
        V[i] = idxs + offsets[i]
    end
    AxisArray(RangeMatrix(V), Axis{:sub}(new_interval_axis(ax, idxs)), Axis{:rep}(ax[offsets]))
end

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
