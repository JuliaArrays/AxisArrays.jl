@doc """
An Interval is a primitive closed interval type.

### Type parameters

```julia
immutable Interval{T}
```
* `T` : the type of the interval

### Constructors

```julia
Interval{T}(a::T,b::T)
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
    Interval(lo, hi) = lo <= hi ? new(lo, hi) : throw(ArgumentError("lo must be less than or equal to hi"))
end
Interval{T}(a::T,b::T) = Interval{T}(a,b)
const .. = Interval

# It'd be nice to use the promotion system for this, but it is intrinsically
# unable to coexist with other "promiscuous" types (like SIUnits)

Base.isless(a::Interval, b::Interval) = isless(a.hi, b.lo)
Base.isless{T}(a::Interval{T}, b::T) = isless(a.hi, b)
Base.isless{T}(a::T, b::Interval{T}) = isless(a, b.lo)

Base.in{T}(a::T, b::Interval{T}) = b.lo <= a <= b.hi
Base.in{T}(a::Interval{T}, b::Interval{T}) = b.lo <= a.lo && a.hi <= b.hi

+(a::Interval, b::Interval) = Interval(a.lo + b.lo, a.hi + b.hi)
+{T}(a::Interval{T}, b::T) = Interval(a.lo + b, a.hi + b)
+{T}(a::T, b::Interval{T}) = Interval(a + b.lo, a + b.hi)
# +{T}(a::Interval{T}, B::AbstractArray{T}) = [Interval(a.lo + b, a.hi + b) for b in B]
# +{T}(A::AbstractArray{T}, b::Interval{T}) = [Interval(a + b.lo, a + b.hi) for a in A]

+(a::Interval) = a


-(a::Interval) = Interval(-a.hi, -a.lo)
-(a::Interval, b::Interval) = a + (-b)


# Maybe use defer computation to allow a mix of indices and values
immutable RepeatedInterval{T, S, A}
    i::Interval{T}
    at::A # A <: AbstractArray{S}
end

RepeatedInterval{T,S}(i::Interval{T}, at::AbstractArray{S}) = RepeatedInterval{T,S,typeof(A)}(i, at)

+{T}(a::Interval{T}, b::AbstractArray) = RepeatedInterval(a, b)
+{T}(b::AbstractArray, a::Interval{T}) = RepeatedInterval(a, b)
