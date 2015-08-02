"""
    RangeMatrix{T<:Range}(rs::AbstractVector{T})

A RangeMatrix is a simple matrix representation of a vector of ranges, with
each range representing one column. Construct a RangeMatrix with a vector of
ranges; the ranges must all have the same length."""
immutable RangeMatrix{T,A} <: AbstractArray{T,2}
    rs::A # A <: AbstractVector{_<:Range{T}}
    dims::Tuple{Int,Int}
end
function RangeMatrix{T<:Range}(rs::AbstractVector{T})
    n = length(rs)
    n == 0 && return RangeMatrix{T}(rs, (0, 0))
    m = length(rs[1])
    for j=2:n
        m == length(rs[j]) || throw(ArgumentError("all UnitRanges must have the same length; expected $m, got $(length(rs[j]))"))
    end
    RangeMatrix{eltype(T), typeof(rs)}(rs, (m, n))
end

Base.size(R::RangeMatrix) = R.dims
Base.linearindexing{R<:RangeMatrix}(::Type{R}) = Base.LinearSlow()

# Scalar indexing
Base.getindex(R::RangeMatrix, i::Int, j::Int) = (checkbounds(R, i, j); Base.unsafe_getindex(R, i, j))
Base.unsafe_getindex(R::RangeMatrix, i::Int, j::Int) = @inbounds return R.rs[j][i]

# For non-scalar indexing, only specialize with inner Ranges and Colons to
# return Ranges or RangeMatrixes. For everything else, we can use the fallbacks.
Base.getindex(R::RangeMatrix, I::Union{Range, Colon}, J) = (checkbounds(R, I, J); Base.unsafe_getindex(R, I, J))
Base.unsafe_getindex(R::RangeMatrix, I::Union{Range, Colon}, j::Real) = @inbounds return R.rs[j][I]
Base.unsafe_getindex(R::RangeMatrix, I::Union{Range, Colon}, ::Colon) = @inbounds return RangeMatrix([R.rs[j][I] for j=1:length(R.rs)])
Base.unsafe_getindex(R::RangeMatrix, I::Union{Range, Colon}, J)       = @inbounds return RangeMatrix([R.rs[j][I] for j in J])
