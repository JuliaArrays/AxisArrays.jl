# Promotion rules for "promiscuous" types like Intervals and SIUnits, which both
# simply wrap any Number, are often ambiguous. That is, which type should "win"
# -- is the promotion between an SIUnit and an ClosedInterval an SIQuantity{ClosedInterval}
# or is it an ClosedInterval{SIQuantity}? For our uses in AxisArrays, though, we can
# sidestep this problem by making Intervals *not* a subtype of Number. Then in
# order for them to plug into the promotion system, we *extend* the promoting
# operator behaviors to Union{Number, ClosedInterval}. This way other types can
# similarly define their own extensions to the promoting operators without fear
# of ambiguity -- there will simply be, e.g.,
#
# f(x::Number, y::Number) = f(promote(x,y)...) # in base
# f(x::Union{Number, ClosedInterval}, y::Union{Number, ClosedInterval}) = f(promote(x,y)...)
# f(x::Union{Number, T}, y::Union{Number, T}) = f(promote(x,y)...)
#
# In this way, these "promiscuous" types will never interact unless explicitly
# made subtypes of Number or otherwise defined with knowledge of eachother. The
# downside is that Intervals are not as useful as they could be; they really
# could be considered as <: Number themselves. We do this in general for any
# supported Scalar:
const Scalar = Union{Number, Dates.AbstractTime}
Base.promote_rule(::Type{ClosedInterval{T}}, ::Type{T}) where {T<:Scalar} = ClosedInterval{T}
Base.promote_rule(::Type{ClosedInterval{T}}, ::Type{S}) where {T,S<:Scalar} = ClosedInterval{promote_type(T,S)}

import Base: isless, <=, >=, ==, +, -, *, /, ^, //
# TODO: Is this a total ordering? (antisymmetric, transitive, total)?
isless(a::ClosedInterval, b::ClosedInterval) = isless(a.right, b.left)
# The default definition for <= assumes a strict total order (<=(x,y) = !(y < x))
<=(a::ClosedInterval, b::ClosedInterval) = a.left <= b.left && a.right <= b.right
+(a::ClosedInterval) = a
+(a::ClosedInterval, b::ClosedInterval) = ClosedInterval(a.left + b.left, a.right + b.right)
-(a::ClosedInterval) = ClosedInterval(-a.right, -a.left)
-(a::ClosedInterval, b::ClosedInterval) = a + (-b)
for f in (:(*), :(/), :(//))
    # For a general monotonic operator, we compute the operation over all
    # combinations of the endpoints and return the widest interval
    @eval function $(f)(a::ClosedInterval, b::ClosedInterval)
        w = $(f)(a.left, b.left)
        x = $(f)(a.left, b.right)
        y = $(f)(a.right, b.left)
        z = $(f)(a.right, b.right)
        ClosedInterval(min(w,x,y,z), max(w,x,y,z))
    end
end

# Extend the promoting operators to include Intervals. The comparison operators
# (<, <=, and ==) are a pain since they are non-promoting fallbacks that call
# isless, !(y < x) (which is wrong), and ===. So implementing promotion with
# Union{T, ClosedInterval} causes stack overflows for the base types. This is safer:
for f in (:isless, :(<=), :(>=), :(==), :(+), :(-), :(*), :(/), :(//))
    # We don't use promote here, though, because promotions can be lossy... and
    # that's particularly bad for comparisons. Just make an interval instead.
    @eval $(f)(x::ClosedInterval, y::Scalar) = $(f)(x, y..y)
    @eval $(f)(x::Scalar, y::ClosedInterval) = $(f)(x..x, y)
end

# And, finally, we have an Array-of-Structs to Struct-of-Arrays transform for
# the common case where the interval is constant over many offsets:
struct RepeatedInterval{T,S,A} <: AbstractVector{T}
    window::ClosedInterval{S}
    offsets::A # A <: AbstractVector
end
RepeatedInterval(window::ClosedInterval{S}, offsets::A) where {S,A<:AbstractVector} =
    RepeatedInterval{promote_type(ClosedInterval{S}, eltype(A)), S, A}(window, offsets)
Base.size(r::RepeatedInterval) = size(r.offsets)
Base.IndexStyle(::Type{<:RepeatedInterval}) = IndexLinear()
Base.getindex(r::RepeatedInterval, i::Int) = r.window + r.offsets[i]
+(window::ClosedInterval, offsets::AbstractVector) = RepeatedInterval(window, offsets)
+(offsets::AbstractVector, window::ClosedInterval) = RepeatedInterval(window, offsets)
-(window::ClosedInterval, offsets::AbstractVector) = RepeatedInterval(window, -offsets)
-(offsets::AbstractVector, window::ClosedInterval) = RepeatedInterval(-window, offsets)

# As a special extension to intervals, we allow specifying Intervals about a
# particular index, which is resolved by an axis upon indexing.
struct IntervalAtIndex{T}
    window::ClosedInterval{T}
    index::Int
end
atindex(window::ClosedInterval, index::Integer) = IntervalAtIndex(window, index)

# And similarly, an AoS -> SoA transform:
struct RepeatedIntervalAtIndexes{T,A<:AbstractVector{Int}} <: AbstractVector{IntervalAtIndex{T}}
    window::ClosedInterval{T}
    indexes::A # A <: AbstractVector{Int}
end
atindex(window::ClosedInterval, indexes::AbstractVector) = RepeatedIntervalAtIndexes(window, indexes)
Base.size(r::RepeatedIntervalAtIndexes) = size(r.indexes)
Base.IndexStyle(::Type{<:RepeatedIntervalAtIndexes}) = IndexLinear()
Base.getindex(r::RepeatedIntervalAtIndexes, i::Int) = IntervalAtIndex(r.window, r.indexes[i])
