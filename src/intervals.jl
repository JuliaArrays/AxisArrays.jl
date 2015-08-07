@doc """
An Interval represents all values between and including its two endpoints.
Intervals are parameterized by the type of its endpoints; this type must be
a concrete leaf type that supports a partial ordering. Promoting arithmetic
is defined for Intervals of `Number` and `Dates.AbstractTime`.

### Type parameters

```julia
immutable Interval{T}
```
* `T` : the type of the interval's endpoints. Must be a concrete leaf type.

### Constructors

```julia
Interval(a, b)
a .. b
```

### Arguments

* `a` : lower bound of the interval
* `b` : upper bound of the interval

### Examples

```julia
A = AxisArray(collect(1:20), Axis{:time}(.1:.1:2.0))
A[Interval(0.2,0.5)]
A[0.0 .. 0.5]
```

""" ->
immutable Interval{T}
    lo::T
    hi::T
    function Interval(lo, hi)
        lo <= hi ? new(lo, hi) : throw(ArgumentError("lo must be less than or equal to hi"))
    end
end
Interval{T}(a::T,b::T) = Interval{T}(a,b)
# Allow promotion during construction, but only if it results in a leaf type
function Interval{T,S}(a::T, b::S)
    R = promote_type(T,S)
    isleaftype(R) || throw(ArgumentError("cannot promote $a and $b to a common leaf type"))
    Interval{R}(promote(a,b)...)
end
const .. = Interval

Base.convert{T}(::Type{Interval{T}}, x::T) = Interval{T}(x,x)
Base.convert{T,S}(::Type{Interval{T}}, x::S) = (y=convert(T, x); Interval{T}(y,y))
Base.convert{T}(::Type{Interval{T}}, w::Interval) = Interval{T}(convert(T, w.lo), convert(T, w.hi))

# Promotion rules for "promiscuous" types like Intervals and SIUnits, which both
# simply wrap any Number, are often ambiguous. That is, which type should "win"
# -- is the promotion between an SIUnit and an Interval an SIQuantity{Interval}
# or is it an Interval{SIQuantity}? For our uses in AxisArrays, though, we can
# sidestep this problem by making Intervals *not* a subtype of Number. Then in
# order for them to plug into the promotion system, we *extend* the promoting
# operator behaviors to Union{Number, Interval}. This way other types can
# similarly define their own extensions to the promoting operators without fear
# of ambiguity -- there will simply be, e.g.,
#
# f(x::Number, y::Number) = f(promote(x,y)...) # in base
# f(x::Union{Number, Interval}, y::Union{Number, Interval}) = f(promote(x,y)...)
# f(x::Union{Number, T}, y::Union{Number, T}) = f(promote(x,y)...)
#
# In this way, these "promiscuous" types will never interact unless explicitly
# made subtypes of Number or otherwise defined with knowledge of eachother. The
# downside is that Intervals are not as useful as they could be; they really
# could be considered as <: Number themselves. We do this in general for any
# supported Scalar:
typealias Scalar Union{Number, Dates.AbstractTime}
Base.promote_rule{T<:Scalar}(::Type{Interval{T}}, ::Type{T}) = Interval{T}
Base.promote_rule{T,S<:Scalar}(::Type{Interval{T}}, ::Type{S}) = Interval{promote_type(T,S)}
Base.promote_rule{T,S}(::Type{Interval{T}}, ::Type{Interval{S}}) = Interval{promote_type(T,S)}

import Base: isless, <=, ==, +, -, *, /, ^
# TODO: Do I want 0..2 < 1..2 ? Should the upper bound be <=?
# TODO: Is this a total ordering? (antisymmetric, transitive, total)? I think so
isless(a::Interval, b::Interval) = isless(a.lo, b.lo) && isless(a.hi, b.hi)
# The default definition for <= assumes a strict total order (<=(x,y) = !(y < x))
<=(a::Interval, b::Interval) = a.lo <= b.lo && a.hi <= b.hi
==(a::Interval, b::Interval) = a.hi == b.hi && a.lo == b.lo
const _interval_hash = UInt == UInt64 ? 0x1588c274e0a33ad4 : 0x1e3f7252
Base.hash(a::Interval, h::UInt) = hash(a.lo, hash(a.hi, hash(_interval_hash, h)))
+(a::Interval) = a
+(a::Interval, b::Interval) = Interval(a.lo + b.lo, a.hi + b.hi)
-(a::Interval) = Interval(-a.hi, -a.lo)
-(a::Interval, b::Interval) = a + (-b)
for f in (:(*), :(/))
    # For a general monotonic operator, we compute the operation over all
    # combinations of the endpoints and return the widest interval
    @eval function $(f)(a::Interval, b::Interval)
        w = $(f)(a.lo, b.lo)
        x = $(f)(a.lo, b.hi)
        y = $(f)(a.hi, b.lo)
        z = $(f)(a.hi, b.hi)
        Interval(min(w,x,y,z), max(w,x,y,z))
    end
end

Base.in(a, b::Interval) = b.lo <= a <= b.hi
Base.in(a::Interval, b::Interval) = b.lo <= a.lo && a.hi <= b.hi
Base.minimum(a::Interval) = a.lo
Base.maximum(a::Interval) = a.hi
# Extend the promoting operators to include Intervals. The comparison operators
# (<, <=, and ==) are a pain since they are non-promoting fallbacks that call
# isless, !(y < x) (which is wrong), and ===. So implementing promotion with
# Union{T, Interval} causes stack overflows for the base types. This is safer:
for f in (:isless, :(<=), :(==), :(+), :(-), :(*), :(/))
    @eval $(f)(x::Interval, y::Scalar) = $(f)(promote(x,y)...)
    @eval $(f)(x::Scalar, y::Interval) = $(f)(promote(x,y)...)
end

# And, finally, we have an Array-of-Structs to Struct-of-Arrays transform for
# the common case where the interval is constant over many offsets:
immutable RepeatedInterval{T,S,A} <: AbstractVector{T}
    window::Interval{S}
    offsets::A # A <: AbstractVector
end
RepeatedInterval{S,A<:AbstractVector}(window::Interval{S}, offsets::A) = RepeatedInterval{promote_type(Interval{S}, eltype(A)), S, A}(window, offsets)
Base.size(r::RepeatedInterval) = size(r.offsets)
Base.linearindexing{R<:RepeatedInterval}(::Type{R}) = Base.LinearFast()
Base.getindex(r::RepeatedInterval, i::Int) = r.window + r.offsets[i]
+(window::Interval, offsets::AbstractVector) = RepeatedInterval(window, offsets)
+(offsets::AbstractVector, window::Interval) = RepeatedInterval(window, offsets)
-(window::Interval, offsets::AbstractVector) = RepeatedInterval(window, -offsets)
-(offsets::AbstractVector, window::Interval) = RepeatedInterval(-window, offsets)

# As a special extension to intervals, we allow specifying Intervals about a
# particular index, which is resolved by an axis upon indexing.
immutable IntervalAtIndex{T}
    window::Interval{T}
    index::Int
end
# TODO: is there a better operator? Maybe a boxed plus ⊞? Or a unicode arrow?
import Base: <|
<|(window::Interval, index::Integer) = IntervalAtIndex(window, index)

# And similarly, an AoS -> SoA transform:
immutable RepeatedIntervalAtIndexes{T,A<:AbstractVector{Int}} <: AbstractVector{IntervalAtIndex{T}}
    window::Interval{T}
    indexes::A # A <: AbstractVector{Int}
end
<|(window::Interval, indexes::AbstractVector) = RepeatedIntervalAtIndexes(window, indexes)
Base.size(r::RepeatedIntervalAtIndexes) = size(r.offsets)
Base.linearindexing{R<:RepeatedIntervalAtIndexes}(::Type{R}) = Base.LinearFast()
Base.getindex(r::RepeatedIntervalAtIndexes, i::Int) = IntervalAtIndex(r.window, r.offsets[i])
