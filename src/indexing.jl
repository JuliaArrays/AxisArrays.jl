### Indexing returns either a scalar or a smartly-subindexed AxisArray ###

# Limit indexing to types supported by SubArrays, at least initially
typealias Idx Union(Colon,Int,Array{Int,1},Range{Int})

# Patch Array indexing to convert Colon() indices to the appropriate UnitRange
if isempty(methods(getindex, (Matrix, Colon, Int)))
    @generated function Base.getindex(A::Array, I::Union(Colon,Real,AbstractVector)...)
        N = length(I)
        idxs = Array(Expr, N)
        for d=1:N-1
            idxs[d] = I[d] <: Colon ? :(1:size(A, $d)) : :(I[$d])
        end
        idxs[N] = I[N] <: Colon ? :(1:Base.trailingsize(A, $N)) : :(I[$N])
        return :(A[$(idxs...)])
    end
    @generated function Base.setindex!(A::Array, v, I::Union(Colon,Real,AbstractArray)...)
        N = length(I)
        idxs = Array(Expr, N)
        for d=1:N-1
            idxs[d] = I[d] <: Colon ? :(1:size(A, $d)) : :(I[$d])
        end
        idxs[N] = I[N] <: Colon ? :(1:Base.trailingsize(A, $N)) : :(I[$N])
        return :(A[$(idxs...)] = v)
    end
end

# Simple scalar indexing where we just set or return scalars
Base.getindex(A::AxisArray) = A.data[]
let args = Expr[], idxs = Symbol[]
    for i = 1:4
        isym = symbol("i$i")
        push!(args, :($isym::Int))
        push!(idxs, isym)
        @eval Base.getindex(A::AxisArray, $(args...)) = A.data[$(idxs...)]
        @eval Base.setindex!(A::AxisArray, v, $(args...)) = (A.data[$(idxs...)] = v)
    end
end
Base.getindex(A::AxisArray, idxs::Int...) = A.data[idxs...]
Base.setindex!(A::AxisArray, v, idxs::Int...) = (A.data[idxs...] = v)

# No-op
Base.getindex{T}(A::AxisArray{T,1}, idx::Colon) = A

# Linear indexing with an array
Base.getindex{S<:Int}(A::AxisArray, idx::AbstractArray{S}) = A.data[idx]
Base.setindex!{S<:Int}(A::AxisArray, v, idx::AbstractArray{S}) = (A.data[idx] = v)

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
    for i = 1:newdims-droplastaxis
        idx = idxs[i] <: Real ? (:(idxs[$i]:idxs[$i])) : (:(idxs[$i]))
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

# Defining the fallbacks on get/setindex are tricky due to ambiguities with 
# AbstractArray definitions... but they simply punt to to_index to convert the
# special indexing forms to integers and integer ranges.
# Even though all these splats look scary, they get inlined and don't allocate.
Base.getindex(A::AxisArray, idx::AbstractArray) = A[to_index(A,idx)...]
Base.setindex!(A::AxisArray, v, idx::AbstractArray) = (A[to_index(A,idx)...] = v)
let rargs = Expr[], aargs = Expr[], idxs = Symbol[]
    for i = 1:4
        isym = symbol("i$i")
        push!(rargs, :($isym::Real))
        push!(aargs, :($isym::Any))
        push!(idxs, isym)
        @eval Base.getindex(A::AxisArray, $(rargs...)) = A[to_index(A,$(idxs...))...]
        @eval Base.setindex!(A::AxisArray, v, $(rargs...)) = (A[to_index(A,$(idxs...))...] = v)
        @eval Base.getindex(A::AxisArray, $(aargs...)) = A[to_index(A,$(idxs...))...]
        @eval Base.setindex!(A::AxisArray, v, $(aargs...)) = (A[to_index(A,$(idxs...))...] = v)
    end
end
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

# These catch-all methods attempt to convert any axis-specific non-standard
# indexing types to their integer or integer range equivalents using axisindexes
# They are separate from the `Base.getindex` function to help alleviate 
# ambiguity warnings from, e.g., `getindex(::AbstractArray, ::Real...)`.
@generated function to_index{T,N,D,Ax}(A::AxisArray{T,N,D,Ax}, I...)
    ex = Expr(:tuple)
    for i=1:length(I)
        if I[i] <: Idx
            push!(ex.args, :(I[$i]))
        elseif i <= length(Ax)
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
