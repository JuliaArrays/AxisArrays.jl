immutable RangeMatrix{T} <: AbstractArray{T,2}
    rs::Vector{UnitRange{T}}
    sz::Int
end

Base.size(R::RangeMatrix) = (R.sz, length(R.rs))
import Base: LinearSlow, unsafe_getindex
Base.linearindexing{R<:RangeMatrix}(::Type{R}) = LinearSlow()
Base.getindex(R::RangeMatrix, i::Int, j::Int) = (checkbounds(R, i, j); unsafe_getindex(R, i, j))
Base.unsafe_getindex(R::RangeMatrix, i::Int, j::Int) = R.rs[j][i]
