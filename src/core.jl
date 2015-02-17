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

# Cartesian iteration
Base.eachindex(A::AxisArray) = eachindex(A.data)
Base.getindex(A::AxisArray, idx::Base.IteratorsMD.CartesianIndex) = A.data[idx]
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

abstract AxisType
immutable Dimensional <: AxisType end
immutable Categorical <: AxisType end
immutable Unsupported <: AxisType end

axistype(v::Any) = error("axes must be vectors of concrete types; $(typeof(v)) is not supported")
axistype(v::AbstractVector) = axistype(eltype(v))
axistype(T::Type) = Unsupported
axistype(T::Type{Int}) = Unsupported # Ints are exclusively for real indexing
axistype{T<:Union(Number, Dates.AbstractTime)}(::Type{T}) = Dimensional
axistype{T<:Union(Symbol, AbstractString)}(::Type{T}) = Categorical

checkaxis(ax) = checkaxes(axistype(ax), ax)
checkaxis(::Type{Unsupported}, ax) = nothing # TODO: warn or error?
# Dimensional axes must be monotonically increasing
checkaxis{T}(::Type{Dimensional}, ax::Range{T}) = step(ax) > zero(T) || error("Dimensional axes must be monotonically increasing")
checkaxis(::Type{Dimensional}, ax) = issorted(ax, lt=(<=)) || error("Dimensional axes must be monotonically increasing")
# Categorical axes must simply be unique
function checkaxis(::Type{Categorical}, ax)
    seen = Set(eltype(ax))
    for elt in ax
        elt in seen && error("Categorical axes must be unique")
        push!(seen, elt)
    end
end

# A very primitive interval type
type Interval{T}
    lo::T
    hi::T
    Interval(lo, hi) = lo <= hi ? new(lo, hi) : error("lo must be less than or equal to hi")
end
Interval{T}(a::T,b::T) = Interval{T}(a,b)
Base.promote_rule{T,S}(::Type{Interval{T}}, ::Type{Interval{S}}) = Interval{promote_type(T,S)}
Base.promote_rule{T,S}(::Type{Interval{T}}, ::Type{S}) = Interval{promote_type(T,S)}
Base.convert{T,S}(::Type{Interval{T}}, x::Interval{S}) = (R = promote_type(T,S); Interval{R}(convert(R,x.lo),(convert(R,x.hi))))
Base.convert{T}(::Type{Interval{T}}, x) = Interval(x,x)
Base.isless(a::Interval, b::Interval) = isless(a.hi, b.lo)
Base.isless(a::Interval, b) = isless(promote(a,b)...)
Base.isless(a, b::Interval) = isless(promote(a,b)...)

# Default axes indexing throws an error
axisindexes(ax, idx) = axisindexes(axistype(ax), ax, idx)
axisindexes(::Type{Unsupported}, ax, idx) = error("elementwise indexing is not supported for axes of type $(typeof(ax))")
# Dimensional axes may be indexed by intervals of their elements
axisindexes{T}(::Type{Dimensional}, ax::AbstractVector{T}, idx::Interval{T}) = searchsorted(ax, idx)
# Categorical axes may be indexed by their elements
function axisindexes{T}(::Type{Categorical}, ax::AbstractVector{T}, idx::T)
    i = findfirst(ax, idx)
    i == 0 && error("index $idx not found")
    i
end
# Categorical axes may be indexed by a vector of their elements
function axisindexes{T}(::Type{Categorical}, ax::AbstractVector{T}, idx::AbstractVector{T}) 
    res = findin(ax, idx)
    length(res) == 0 && error("index $idx not found")
    res
end

# TODO: why do I need the unused static parameters? (stack overflow otherwise)
# TODO: this throws ambiguity warnings for idxs that are covered in Unions above
# TODO: this could be much more efficient, eliminate splatting, etc.
function Base.getindex{T,N,D,names,Ax,AxElt}(A::AxisArray{T,N,D,names,Ax,AxElt}, idxs...)
    reidx = ntuple(length(idxs)) do i
        isa(idxs[i], Idx) || i > length(A.axes) ? idxs[i] : axisindexes(A.axes[i], idxs[i])
    end
    getindex(A, reidx...)
end
