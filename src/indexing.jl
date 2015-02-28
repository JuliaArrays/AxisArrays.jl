### Indexing returns either a scalar or a smartly-subindexed AxisArray ###

# Limit indexing to types supported by SubArrays, at least initially
typealias Idx Union(Colon,Int,Array{Int,1},Range{Int})

# Simple scalar indexing where we just set or return scalars
Base.getindex{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}) = A.data[]
let args = Expr[], idxs = Symbol[]
    for i = 1:4
        isym = symbol("i$i")
        push!(args, :($isym::Int))
        push!(idxs, isym)
        @eval Base.getindex(A::AxisArray, $(args...)) = A.data[$(idxs...)]
        @eval Base.setindex!(A::AxisArray, v, $(args...)) = (A.data[$(idxs...)] = v)
    end
end
Base.getindex{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, idxs::Int...) = A.data[idxs...]
Base.setindex!{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, v, idxs::Int...) = (A.data[idxs...] = v)

# No-op
Base.getindex{T,D,names,Ax}(A::AxisArray{T,1,D,names,Ax}, idx::Colon) = A

# Linear indexing with an array
Base.getindex{T,N,D,names,Ax,S<:Int}(A::AxisArray{T,N,D,names,Ax}, idx::AbstractArray{S}) = A.data[idx]
Base.setindex!{T,N,D,names,Ax,S<:Int}(A::AxisArray{T,N,D,names,Ax}, v, idx::AbstractArray{S}) = (A.data[idx] = v)

# Cartesian iteration
Base.eachindex(A::AxisArray) = eachindex(A.data)
Base.getindex(A::AxisArray, idx::Base.IteratorsMD.CartesianIndex) = A.data[idx]
Base.setindex!(A::AxisArray, v, idx::Base.IteratorsMD.CartesianIndex) = (A.data[idx] = v)

# More complicated cases where we must create a subindexed AxisArray
# TODO: do we want to be dogmatic about using views? For the data? For the axes?
# TODO: perhaps it would be better to return an entirely lazy SubAxisArray view
stagedfunction Base.getindex{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, idxs::Idx...)
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
        $(AxisArray{T,newdims,newdata,newnames,newaxes})(data, $axes)
    end
end
# Setindex is so much simpler. Just assign it to the data:
Base.setindex!{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, v, idxs::Idx...) = (A.data[idxs...] = v)

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

# Defining the fallbacks on get/setindex are tricky due to ambiguities with 
# AbstractArray definitions... but they simply punt to to_index to convert the
# special indexing forms to integers and integer ranges.
# Even though all these splats look scary, they get inlined and don't allocate.
Base.getindex{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, idx::AbstractArray) = A[to_index(A,idx)...]
Base.setindex!{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, v, idx::AbstractArray) = (A[to_index(A,idx)...] = v)
let rargs = Expr[], aargs = Expr[], idxs = Symbol[]
    for i = 1:4
        isym = symbol("i$i")
        push!(rargs, :($isym::Real))
        push!(aargs, :($isym::Any))
        push!(idxs, isym)
        @eval Base.getindex{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, $(rargs...)) = A[to_index(A,$(idxs...))...]
        @eval Base.setindex!{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, v, $(rargs...)) = (A[to_index(A,$(idxs...))...] = v)
        @eval Base.getindex{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, $(aargs...)) = A[to_index(A,$(idxs...))...]
        @eval Base.setindex!{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, v, $(aargs...)) = (A[to_index(A,$(idxs...))...] = v)
    end
end
Base.getindex{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, idxs...) = A[to_index(A,idxs...)...]
Base.setindex!{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, v, idxs...) = (A[to_index(A,idxs...)...] = v)


# First is indexing by named axis. We simply sort the axes and re-dispatch.
# When indexing by named axis the shapes of omitted dimensions are preserved
# TODO: should we handle multidimensional Axis indexes? It could be interpreted
#       as adding dimensions in the middle of an AxisArray.
# TODO: should we allow repeated axes? As a union of indices of the duplicates?
stagedfunction to_index{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, I::Axis...)
    dims = Int[axisdim(A, ax) for ax in I]
    idxs = Expr[:(Colon()) for d = 1:N]
    for i=1:length(dims)
        idxs[dims[i]] == :(Colon()) || return :(error("multiple indices provided on axis ", $(names[dims[i]])))
        idxs[dims[i]] = :(I[$i].I)
    end

    meta = Expr(:meta, :inline)
    return :($meta; to_index(A, $(idxs...)))
end

### Indexing along values of the axes ###

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
    length(res) == length(idx) || error("index $(setdiff(idx,ax)) not found")
    res
end

# These catch-all methods attempt to convert any axis-specific non-standard
# indexing types to their integer or integer range equivalents using axisindexes
# They are separate from the `Base.getindex` function to help alleviate 
# ambiguity warnings from, e.g., `getindex(::AbstractArray, ::Real...)`.
stagedfunction to_index{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, I...)
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
