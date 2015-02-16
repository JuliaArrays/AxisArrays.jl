# Core types and definitions

immutable AxisArray{T,N,D<:AbstractArray,names,Ax,AxElts} <: AbstractArray{T,N}
    data::D
    axes::Ax
end
# Allow AxisArrays that are missing dimensions and/or names?
AxisArray{T,N}(A::AbstractArray{T,N}, axes::(AbstractVector...)=()) =
    AxisArray(A, axes, N==0 ? () : N==1 ? (:row,) : N==2 ? (:row,:col) : (:row,:col,:page))
stagedfunction AxisArray{T,N}(A::AbstractArray{T,N}, axes::(AbstractVector...), names::(Symbol...))
    Ax = axes == Type{()} ? () : axes # Tuple's Type/Value duality is painful
    AxElts = map(eltype,Ax)
    :(AxisArray{T,N,$A,names,$Ax,$AxElts}(A, axes))
end

# Type-stable axis-specific indexing and identification with a parametric type:
immutable Axis{name,T}
    I::T
end
# Constructed exclusively through Axis{:symbol}(...)
call{name,T}(::Type{Axis{name}}, I::T=()) = Axis{name,T}(I)
Base.isempty(ax::Axis) = isempty(ax.I)
# TODO: I'd really like to only have one of axisnames/axisname.
axisname(ax::Axis) = axisname(typeof(ax))
axisname{name,T}(::Type{Axis{name,T}}) = name
axisname{name}(::Type{Axis{name}}) = name # Invariance. Is this a real concern?

# Base definitions that aren't provided by AbstractArray
Base.size(A::AxisArray) = size(A.data)
Base.linearindexing(A::AxisArray) = Base.linearindexing(A.data)

# Custom methods specific to AxisArrays
axisnames(A::AxisArray) = axisnames(typeof(A))
axisnames{T,N,D,names,Ax,AxElts}(::Type{AxisArray{T,N,D,names,Ax,AxElts}}) = names
axisnames{T,N,D,names,Ax}(::Type{AxisArray{T,N,D,names,Ax}}) = names
axisnames{T,N,D,names}(::Type{AxisArray{T,N,D,names}}) = names
axes(A::AxisArray) = A.axes
axes(A::AxisArray,i::Int) = A.axes[i]

### Indexing returns either a scalar or a smartly-subindexed AxisArray ###

# Limit indexing to types supported by SubArrays, at least initially
typealias Idx Union(Colon,Int,Array{Int,1},Range{Int})

# Simple scalar indexing where we return scalars
Base.getindex(A::AxisArray) = A.data[]
Base.getindex{T,N,D,names,Ax,AxElt}(A::AxisArray{T,N,D,names,Ax,AxElt}) = A.data[]
let args = Expr[], idxs = Symbol[]
    for i = 1:4
        isym = symbol("i$i")
        push!(args, :($isym::Int))
        push!(idxs, isym)
        @eval Base.getindex{T}(A::AxisArray{T,$i}, $(args...)) = A.data[$(idxs...)]
    end
end
Base.getindex{T,N}(A::AxisArray{T,N}, idxs::Int...) = A.data[idxs...]

# More complicated cases where we must create a subindexed AxisArray
# TODO: do we want to be dogmatic about using views? For the data? For the axes?
# TODO: perhaps it would be better to return an entirely lazy SubAxisArray view
stagedfunction Base.getindex{T,N,D,names,Ax,AxElt}(A::AxisArray{T,N,D,names,Ax,AxElt}, idxs::Idx...)
    newdims = length(idxs)
    # If the last index is a linear indexing range that may span multiple
    # dimensions in the original AxisArray, we can no longer track those axes.
    droplastaxis = N > newdims && !(idxs[end] <: Real) ? 1 : 0
    # There might be a case here for preserving trailing scalar dimensions
    # within the axes... but for now let's drop them.
    while newdims > 0 && idxs[newdims] <: Real
        newdims -= 1
    end
    newdata = _sub_type(D, idxs)
    newnames = names[1:min(newdims-droplastaxis, length(names))]
    newaxes = Ax[1:min(newdims-droplastaxis, length(Ax))]
    newaxelts = AxElt[1:min(newdims-droplastaxis, length(AxElt))]
    axes = Expr(:tuple)
    for i = 1:length(newaxes)
        if idxs[i] <: Real
            # This needs to preserve the type of the axes, so scalar indices
            # must become ranges. This is really hacky and will fail if
            # indexing the axis vector by a UnitRange returns a different type.
            push!(axes.args, :(A.axes[$i][idxs[$i]:idxs[$i]]))
        else
            push!(axes.args, :(A.axes[$i][idxs[$i]]))
        end
    end
    quote
        data = sub(A.data, idxs...) # TODO: create this Expr to avoid splatting
        isa(data, $newdata) || error("miscomputed subarray type: computed ", $newdata, ", got ", typeof(data))
        $(AxisArray{T,newdims,newdata,newnames,newaxes,newaxelts})(data, $axes)
    end
end

# Stolen and stripped down from the Base stagedfunction _sub:
function _sub_type(A, I)
    sizeexprs = Array(Any, 0)
    Itypes = Array(Any, 0)
    T = eltype(A)
    N = length(I)
    while N > 0 && I[N] <: Real
        N -= 1
    end
    for k = 1:length(I)
        if k < N && I[k] <: Real
            push!(Itypes, UnitRange{Int})
        else
            push!(Itypes, I[k])
        end
    end
    It = tuple(Itypes...)
    LD = Base.subarray_linearindexing_dim(A, I)
    SubArray{T,N,A,It,LD}
end


### Fancier indexing capabilities provided only by AxisArrays ###

# First is the ability to index by named axis.
# When indexing by named axis the shapes of omitted dimensions are preserved
# TODO: should we handle multidimensional Axis indexes? It could be interpreted
#       as adding dimensions in the middle of an AxisArray.
# TODO: should we allow repeated axes? As a union of indices of the duplicates?
stagedfunction Base.getindex{T,N,D,names,Ax,AxElt}(A::AxisArray{T,N,D,names,Ax,AxElt}, I::Axis...)
    Inames = Symbol[axisname(i) for i in I]
    Anames = Symbol[names...]
    ind = indexin(Inames, Anames)
    for i = 1:length(ind)
        ind[i] == 0 && return :(error("axis name ", $(Inames[i]), " is not in ", $names))
    end

    idxs = Expr[:(Colon()) for d = 1:N]
    for i=1:length(ind)
        idxs[ind[i]] == :(Colon()) || return :(error("multiple indices provided on axis ", $(names[ind[i]])))
        idxs[ind[i]] = :(I[$i].I)
    end

    return :(A[$(idxs...)])
end

### Indexing with the element type of the axes ###

# Default axes indexing does nothing
axesindexes(ax, idx) = idx

# A Symbol vector is an Axis to be indexed by a Symbol or Array of Symbols
axesindexes(ax::Array{Symbol,1}, idx::Symbol) = findfirst(ax, idx) || error("index $idx not found") # BROKEN
axesindexes(ax::Array{Symbol,1}, idx::Array{Symbol,1}) = findin(ax, idx)

# FloatRange is a Regular Signal Axis to be indexed by an array to select a range (from min to max)
function axesindexes{T}(ax::FloatRange{T}, idx::Array{T,1})
    mn = minimum(idx)
    mx = maximum(idx)
    from = mn <= minimum(ax) ? 1 : 1 + int(ceil(ax.divisor * (mn - minimum(ax)) / ax.step))
    to = mx >= maximum(ax) ? length(ax) : length(ax) - int(ceil(ax.divisor * (maximum(ax) - mx) / ax.step))
    from:to
end


# Ordered is an irregular Signal Axis to be indexed by an array to select a range (from min to max)
export Ordered
type Ordered{T,S} <: AbstractArray{T,1}
    # TODO: needs checks
    data::S
end
Ordered{T}(a::AbstractVector{T}) = Ordered{T, typeof(a)}(a)
Base.getindex(a::Ordered, idx::UnitRange) = Ordered(a.data[idx])
Base.length(a::Ordered) = length(a.data)
Base.eltype{T,S}(a::Ordered{T,S}) = T
function axesindexes{T,S}(ax::Ordered{T,S}, idx::Array{T,1})
    mn = minimum(idx)
    mx = maximum(idx)
    from = mn <= ax.data[1] ? 1 : searchsortedfirst(ax.data, mn)
    to = mx >= ax.data[end] ? length(ax.data) : searchsortedlast(ax.data, mx)
    from:to
end
