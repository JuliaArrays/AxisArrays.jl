# Core types and definitions

@doc """
An AxisArray is an AbstractArray that wraps another AbstractArray and
adds axis names and values to each array dimension. AxisArrays can be indexed
by using the named axes as an alternative to positional indexing by
dimension. Other advanced indexing along axis values are also provided.

### Type parameters

The AxisArray contains several type parameters:

```julia
immutable AxisArray{T,N,D<:AbstractArray,names,Ax} <: AbstractArray{T,N}
```
* `T` : the elemental type of the AbstractArray
* `N` : the number of dimensions
* `D` : the type of the wrapped AbstractArray
* `names` : the names of each axis, a tuple of Symbols of length `D` or less
* `Ax` : the types of each axis, a tuple of types of length `D` or less

### Constructors

```julia
AxisArray(A::AbstractArray[, names::(Symbol...)][, axes::(AbstractVector...)])
```

### Arguments

* `A::AbstractArray` : the wrapped array data
* `axes::(AbstractVector...)` : an optional tuple of AbstractVectors, one for
  each dimension of `A`. The length of the `i`th vector must equal `size(A, i)`.
  Defaults to `()`.
* `names::(Symbol...)` : an optional tuple of Symbols, to name
  the dimensions of `A`. For dimensions up to three, defaults
  to `(:row,:col,:page)` with any higher dimensions unnamed.
* The `names` and `axes` arguments may be given in either order.

### Indexing

Indexing returns a view into the original data. The returned view is a
new AxisArray that wraps a SubArray. Indexing should be type
stable. Use `Axis{axisname}(idx)` to index based on a specific
axis. `axisname` is a Symbol specifying the axis to index/slice, and
`idx` is a normal indexing object (`Int`, `Array{Int,1}`, etc.) or a
custom indexing type for that particular type of axis.

Two main types of axes supported by default include:

* Categorical axis -- These are vectors of labels, normally symbols or
  strings. Elements or slices can be indexed by elements or vectors
  of elements.

* Dimensional axis -- These are sorted vectors or iterators that can
  be indexed by `Interval()`. These are commonly used for sequences of
  times or date-times. For regular sample rates, ranges can be used.

User-defined axis types can be added along with custom indexing
behaviors. To add add a custom type as a Categorical or Dimensional
axis, add a trait using `AxisArrays.axistype`. Here is the example of
adding a custom Dimensional axis:

```julia
AxisArrays.axistype(v::MyCustomAxis) = AxisArrays.Dimensional
```

For more advanced indexing, you can define custom methods for
`AxisArrays.axisindexes`.


### Examples

Here is an example with a Dimensional axis representing a time
sequence along rows (it's a FloatRange) and a Categorical axis of
symbols for column headers.

```julia
A = AxisArray(reshape(1:15, 5,3), (.1:.1:0.5, [:a, :b, :c]), (:time, :col))
A[Axis{:time}(1:3)]   # equivalent to A[1:3,:]
A[Axis{:time}(Interval(.2,.4))] # restrict the AxisArray along the time axis
A[Interval(0.,.3), [:a, :c]]   # select an interval and two columns 
```

""" ->
immutable AxisArray{T,N,D<:AbstractArray,names,Ax} <: AbstractArray{T,N}
    data::D
    axes::Ax
    function AxisArray(data, axes)
        for i = 1:length(axes)
            checkaxis(axes[i])
            length(axes[i]) == size(data, i) || error("the length of each axis must match the corresponding size of data")
        end
        length(axes) <= ndims(data) || error("there may not be more axes than dimensions of data")
        length(names) <= ndims(data) || error("there may not be more axis names than dimensions of data")
        new{T,N,D,names,Ax}(data, axes)
    end
end
AxisArray{T,N}(A::AbstractArray{T,N}, ::()) =
    AxisArray{T,N,typeof(A),(:row,:col,:page)[1:min(N,3)],()}(A, ())
AxisArray{T,N}(A::AbstractArray{T,N}, ::(), ::()) =
    AxisArray{T,N,typeof(A),(),()}(A, ())
AxisArray{T,N}(A::AbstractArray{T,N}, names::(Symbol...)=(:row,:col,:page)[1:min(N,3)], axes::(AbstractVector...)=()) =
    AxisArray{T,N,typeof(A),names,typeof(axes)}(A, axes)
AxisArray{T,N}(A::AbstractArray{T,N}, axes::(AbstractVector...)=(), names::(Symbol...)=(:row,:col,:page)[1:min(N,3)]) =
    AxisArray{T,N,typeof(A),names,typeof(axes)}(A, axes)

@doc """
Type-stable axis-specific indexing and identification with a
parametric type.

### Type parameters

```julia
immutable Axis{name,T}
```
* `name` : the name of the axis, a Symbol
* `T` : the type of the axis

### Constructors

```julia
Axis{name}(I)
```

### Arguments

* `name` : the axis name symbol or integer dimension
* `I` : the indexer, any indexing type that the axis supports

### Examples

Here is an example with a Dimensional axis representing a time
sequence along rows and a Categorical axis of symbols for column
headers.

```julia
A = AxisArray(reshape(1:60, 12, 5), (.1:.1:1.2, .1:.1:.5), (:row, :col))
A[Axis{:col}(2)] # grabs the second column
A[Axis{:row}(2)] # grabs the second row
A[Axis{2}(2:5)] # grabs the second through 5th columns
```

""" ->
immutable Axis{name,T}
    I::T
end
# Constructed exclusively through Axis{:symbol}(...)
call{name,T}(::Type{Axis{name}}, I::T=()) = Axis{name,T}(I)
Base.isempty(ax::Axis) = isempty(ax.I)
@doc """
axisdim(::Type{AxisArray}, ::Type{Axis}) -> Int

Given the types of an AxisArray and an Axis, return the integer dimension of 
the Axis within the array.
"""
function axisdim{T,N,D,names,Ax,name,S}(::Type{AxisArray{T,N,D,names,Ax}}, ::Type{Axis{name,S}})
    isa(name, Int) && return name <= N ? name : error("axis $name greater than array dimensionality $N")
    idx = findfirst(names, name)
    idx == 0 && error("axis $name not found in array axes $names")
    idx
end

# Base definitions that aren't provided by AbstractArray
Base.size(A::AxisArray) = size(A.data)
Base.linearindexing(A::AxisArray) = Base.linearindexing(A.data)

# Custom methods specific to AxisArrays
axisnames(A::AxisArray) = axisnames(typeof(A))
axisnames{T,N,D,names,Ax}(::Type{AxisArray{T,N,D,names,Ax}}) = names
axisnames{T,N,D,names,Ax}(::Type{AxisArray{T,N,D,names,Ax}}) = names
axisnames{T,N,D,names}(::Type{AxisArray{T,N,D,names}}) = names
axes(A::AxisArray) = A.axes
axes(A::AxisArray,i::Int) = A.axes[i]

### Indexing returns either a scalar or a smartly-subindexed AxisArray ###

# Limit indexing to types supported by SubArrays, at least initially
typealias Idx Union(Colon,Int,Array{Int,1},Range{Int})

# Simple scalar indexing where we return scalars
Base.getindex{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}) = A.data[]
let args = Expr[], idxs = Symbol[]
    for i = 1:4
        isym = symbol("i$i")
        push!(args, :($isym::Int))
        push!(idxs, isym)
        @eval Base.getindex{T}(A::AxisArray{T,$i}, $(args...)) = A.data[$(idxs...)]
    end
end
Base.getindex{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, idxs::Int...) = A.data[idxs...]

# No-op
Base.getindex{T,D,names,Ax}(A::AxisArray{T,1,D,names,Ax}, idx::Colon) = A

# Linear indexing with an array
Base.getindex{T,N,D,names,Ax,S<:Int}(A::AxisArray{T,N,D,names,Ax}, idx::AbstractArray{S}) = A.data[idx]

# Cartesian iteration
Base.eachindex(A::AxisArray) = eachindex(A.data)
Base.getindex(A::AxisArray, idx::Base.IteratorsMD.CartesianIndex) = A.data[idx]

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
stagedfunction Base.getindex{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, I::Axis...)
    dims = Int[axisdim(A, ax) for ax in I]
    idxs = Expr[:(Colon()) for d = 1:N]
    for i=1:length(dims)
        idxs[dims[i]] == :(Colon()) || return :(error("multiple indices provided on axis ", $(names[dims[i]])))
        idxs[dims[i]] = :(I[$i].I)
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

checkaxis(ax) = checkaxis(axistype(ax), ax)
checkaxis(::Type{Unsupported}, ax) = nothing # TODO: warn or error?
# Dimensional axes must be monotonically increasing
checkaxis{T}(::Type{Dimensional}, ax::Range{T}) = step(ax) > zero(T) || error("Dimensional axes must be monotonically increasing")
checkaxis(::Type{Dimensional}, ax) = issorted(ax, lt=(<=)) || error("Dimensional axes must be monotonically increasing")
# Categorical axes must simply be unique
function checkaxis(::Type{Categorical}, ax)
    seen = Set{eltype(ax)}()
    for elt in ax
        elt in seen && error("Categorical axes must be unique")
        push!(seen, elt)
    end
end

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
    length(res) == length(idx) || error("index $(setdiff(idx,ax)) not found")
    res
end

# Defining the fallbacks on getindex are tricky due to ambiguities with 
# AbstractArray definitions - 
let args = Expr[], idxs = Symbol[]
    for i = 1:4
        isym = symbol("i$i")
        push!(args, :($isym::Real))
        push!(idxs, isym)
        @eval Base.getindex{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, $(args...)) = fallback_getindex(A, $(idxs...))
    end
end
Base.getindex{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, idx::AbstractArray) = fallback_getindex(A, idx)
Base.getindex{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, idxs...) = fallback_getindex(A, idxs...)

# These catch-all methods attempt to convert any axis-specific non-standard
# indexing types to their integer or integer range equivalents using the
# They are separate from the `Base.getindex` function to help alleviate 
# ambiguity warnings from, e.g., `getindex(::AbstractArray, ::Real...)`.
# TODO: These could be generated with meta-meta-programming
stagedfunction fallback_getindex{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, I1)
    ex = :(getindex(A))
    push!(ex.args, I1 <: Idx || length(Ax) < 1 ? :(I1) : :(axisindexes(A.axes[1], I1)))
    ex
end
stagedfunction fallback_getindex{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, I1, I2)
    ex = :(getindex(A))
    push!(ex.args, I1 <: Idx || length(Ax) < 1 ? :(I1) : :(axisindexes(A.axes[1], I1)))
    push!(ex.args, I2 <: Idx || length(Ax) < 2 ? :(I2) : :(axisindexes(A.axes[2], I2)))
    ex
end
stagedfunction fallback_getindex{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, I1, I2, I3)
    ex = :(getindex(A))
    push!(ex.args, I1 <: Idx || length(Ax) < 1 ? :(I1) : :(axisindexes(A.axes[1], I1)))
    push!(ex.args, I2 <: Idx || length(Ax) < 2 ? :(I2) : :(axisindexes(A.axes[2], I2)))
    push!(ex.args, I3 <: Idx || length(Ax) < 3 ? :(I3) : :(axisindexes(A.axes[3], I3)))
    ex
end
stagedfunction fallback_getindex{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, I1, I2, I3, I4)
    ex = :(getindex(A))
    push!(ex.args, I1 <: Idx || length(Ax) < 1 ? :(I1) : :(axisindexes(A.axes[1], I1)))
    push!(ex.args, I2 <: Idx || length(Ax) < 2 ? :(I2) : :(axisindexes(A.axes[2], I2)))
    push!(ex.args, I3 <: Idx || length(Ax) < 3 ? :(I3) : :(axisindexes(A.axes[3], I3)))
    push!(ex.args, I4 <: Idx || length(Ax) < 4 ? :(I4) : :(axisindexes(A.axes[4], I4)))
    ex
end
stagedfunction fallback_getindex{T,N,D,names,Ax}(A::AxisArray{T,N,D,names,Ax}, I...)
    ex = :(getindex(A))
    for i=1:length(I)
        push!(ex.args, I[i] <: Idx || length(Ax) < i ? :(I[$i]) : :(axisindexes(A.axes[$i], I[$i])))
    end
    ex
end
