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
""" ->
stagedfunction axisdim{T<:Axis}(A::AxisArray, ax::Type{T})
    dim = axisdim(A, ax)
    :($dim)
end
axisdim{T,N,D,names,Ax,name,S}(A::Type{AxisArray{T,N,D,names,Ax}}, ::Type{Axis{name,S}}) = axisdim(A, Type{Axis{name}})
function axisdim{T,N,D,names,Ax,name}(::Type{AxisArray{T,N,D,names,Ax}}, ::Type{Type{Axis{name}}})
    isa(name, Int) && return name <= N ? name : error("axis $name greater than array dimensionality $N")
    idx = findfirst(names, name)
    idx == 0 && error("axis $name not found in array axes $names")
    idx
end

# Base definitions that aren't provided by AbstractArray
Base.size(A::AxisArray) = size(A.data)
Base.linearindexing(A::AxisArray) = Base.linearindexing(A.data)

# Custom methods specific to AxisArrays
@doc """
    axisnames(A::AxisArray) -> (Symbol...)
    axisnames(::Type{AxisArray{...}}) -> (Symbol...)

Returns the axis names of an AxisArray or AxisArray Type as a tuple of symbols.
""" ->
axisnames(A::AxisArray) = axisnames(typeof(A))
axisnames{T,N,D,names,Ax}(::Type{AxisArray{T,N,D,names,Ax}}) = names
axisnames{T,N,D,names,Ax}(::Type{AxisArray{T,N,D,names,Ax}}) = names
axisnames{T,N,D,names}(::Type{AxisArray{T,N,D,names}}) = names
axes(A::AxisArray) = A.axes
axes(A::AxisArray,i::Int) = A.axes[i]

### Axis traits ###
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
