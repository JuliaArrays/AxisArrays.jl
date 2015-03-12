@doc """
A primitive interval type.

### Type parameters

```julia
immutable Interval{T}
```
* `T` : the type of the interval

### Constructors

```julia
Interval{T}(a::T,b::T)
```

### Arguments

* `a` : lower bound of the interval
* `b` : upper bound of the interval

### Examples

```julia
A = AxisArray(collect(1:20), (.1:.1:2.0,), (:time,))
A[Interval(0.0,0.5)]
A[Interval(0.2,0.5)]
```

""" ->
immutable Interval{T}
    lo::T
    hi::T
    Interval(lo, hi) = lo <= hi ? new(lo, hi) : throw(ArgumentError("lo must be less than or equal to hi"))
end
Interval{T}(a::T,b::T) = Interval{T}(a,b)
Base.promote_rule{T,S}(::Type{Interval{T}}, ::Type{Interval{S}}) = Interval{promote_type(T,S)}
Base.promote_rule{T}(::Type{Interval{T}}, ::Type{T}) = Interval{T}
Base.convert{T,S}(::Type{Interval{T}}, x::Interval{S}) = Interval{T}(convert(T,x.lo),(convert(T,x.hi)))
Base.convert{T}(::Type{Interval{T}}, x) = Interval(x,x)
Base.isless(a::Interval, b::Interval) = isless(a.hi, b.lo)
Base.isless(a::Interval, b) = isless(promote(a,b)...)
Base.isless(a, b::Interval) = isless(promote(a,b)...)
