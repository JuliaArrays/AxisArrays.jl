module NamedAxesArrays

import Base: eltype, getindex, ndims, setindex!

immutable NamedAxesArray{T,N,A<:AbstractArray,axisnames<:(Symbol...)} <: AbstractArray{T,N}
    data::A
end
NamedAxesArray{T,N}(A::AbstractArray{T,N}, axisnames::NTuple{N,Symbol}) = NamedAxes{T,N,typeof(A),axisnames}(A)

   eltype{T,N,A,axisnames}(::Type{NamedAxesArray{T,N,A,axisnames}}) = T
    ndims{T,N,A,axisnames}(::Type{NamedAxesArray{T,N,A,axisnames}}) = N
axisnames{T,N,A,axisnames}(::Type{NamedAxesArray{T,N,A,axisnames}}) = axisnames
   eltype{T,N,A,axisnames}(A::NamedAxesArray{T,N,A,axisnames}) = T
    ndims{T,N,A,axisnames}(A::NamedAxesArray{T,N,A,axisnames}) = N
axisnames{T,N,A,axisnames}(A::NamedAxesArray{T,N,A,axisnames}) = axisnames

immutable NamedAxis{axisname<:Symbol,T}
    I::T
end
NamedAxis{T}(name::Symbol, I::T) = NamedAxis{name,T}(I)

axisname{S,T}(i::NamedAxis{S,T}) = S
axistype{S,T}(i::NamedAxis{S,T}) = T
axisname{S,T}(::Type{NamedAxis{S,T}}) = S
axistype{S,T}(::Type{NamedAxis{S,T}}) = T


### Traditional position-based indexing ###
typealias RegularIndex{R} Union(R, AbstractVector{R})
# Efficient unsplatted variants
let params = Expr[], args = Expr[], indexes = Symbol[]
for i = 1:4
    Rsym = symbol("R$i")
    isym = symbol("i$i")
    push!(params, :($Rsym<:Real))
    push!(args, :($isym::RegularIndex{$Rsym}))
    push!(indexes, isym)
    @eval begin
        getindex{$(params...)}(A::NamedAxesArray, $(args...)) = A.data[$(indexes...)]
        setindex!{$(params...)}(A::NamedAxesArray, v, $(args...)) = A.data[$(indexes...)] = v
    end
end
# Splatted variants for higher dimensions
getindex(A::NamedAxesArray, I::Union(Real, AbstractVector)...) = A.data[I...]
setindex!(A::NamedAxesArray, v, I::Union(Real, AbstractVector)...) = A.data[I...] = v


### Indexing using the axis names ###
# For integer-valued dimensions, this has slicing semantics
stagedfunction getindex(A::NamedAxesArray, i1::NamedAxis)
    getindex_gen(A, i1)
end
stagedfunction getindex(A::NamedAxesArray, i1::NamedAxis, i2::NamedAxis)
    getindex_gen(A, i1, i2)
end
stagedfunction getindex(A::NamedAxesArray, i1::NamedAxis, i2::NamedAxis, i3::NamedAxis)
    getindex_gen(A, i1, i2, i3)
end
stagedfunction getindex(A::NamedAxesArray, i1::NamedAxis, i2::NamedAxis, i3::NamedAxis, i4::NamedAxis)
    getindex_gen(A, i1, i2, i3, i4)
end

function getindex_gen(A, indexes...)
    anames = [map(axisname, indexes)...]
    Anames = [axisnames(A)...]
    nd = ndims(A)
    ind = indexin(anames, Anames)
    for i = 1:length(ind)
        if ind[i] == 0
        return :(error("axis name $(anames[i]) is not in $(axisnames(A))"))
    end
    indexexprs = [:(1:size(A,d)) for d = 1:nd]
    indextypes = [Range{Int} for d = 1:nd]
    for i = 1:length(ind)
        indexexprs[ind[i]] = :(indexes[i].I)
        indextypes[ind[i]] = axistype(indexes[i])
    end
    sliceindexes = filter(d -> axistypes[d]<:Real, 1:nd)
    deleteat!(Anames, sliceindexes)
    AvT = viewapl1(A, indextypes...)  # viewapl1 throws an error when indexing with higher-dimensional array indexes
    :(NamedAxesArray{$(eltype(AvT)),$(ndims(AvT)), $AvT, $(tuple(Anames...))}(viewapl1(A, $(indexexprs...))))
end

end
