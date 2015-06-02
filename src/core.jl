# Core types and definitions

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
A = AxisArray(reshape(1:60, 12, 5), .1:.1:1.2, [:a, :b, :c, :d, :e])
A[Axis{:col}(2)] # grabs the second column
A[Axis{:col}(:b)] # Same as above, grabs column :b (the second column)
A[Axis{:row}(2)] # grabs the second row
A[Axis{2}(2:5)] # grabs the second through 5th columns
```

""" ->
immutable Axis{name,T}
    val::T
end
# Constructed exclusively through Axis{:symbol}(...) or Axis{1}(...)
Base.call{name,T}(::Type{Axis{name}}, I::T=()) = Axis{name,T}(I)
Base.(:(==)){name,T}(A::Axis{name,T}, B::Axis{name,T}) = A.val == B.val
Base.hash{name}(A::Axis{name}, hx::Uint) = hash(A.val, hash(name, hx))
axistype{name,T}(::Axis{name,T}) = T
axistype{name,T}(::Type{Axis{name,T}}) = T

@doc """
An AxisArray is an AbstractArray that wraps another AbstractArray and
adds axis names and values to each array dimension. AxisArrays can be indexed
by using the named axes as an alternative to positional indexing by
dimension. Other advanced indexing along axis values are also provided.

### Type parameters

The AxisArray contains several type parameters:

```julia
immutable AxisArray{T,N,D,Ax} <: AbstractArray{T,N}
```
* `T` : the elemental type of the AbstractArray
* `N` : the number of dimensions
* `D` : the type of the wrapped AbstractArray
* `Ax` : the names and types of the axes, as a (specialized) NTuple{N, Axis}

### Constructors

```julia
AxisArray(A::AbstractArray, axes::Axis...)
AxisArray(A::AbstractArray, names::Symbol...)
AxisArray(A::AbstractArray, vectors::AbstractVector...)
```

### Arguments

* `A::AbstractArray` : the wrapped array data
* `axes` or `names` or `vectors` : dimensional information for the wrapped array

The dimensional information may be passed in one of three ways and is entirely
optional. When the axis name or value is missing for a dimension, a default is
substituted. The default axis names for dimensions `(1, 2, 3, 4, 5, ...)` are
`(:row, :col, :page, :dim_4, :dim_5, ...)`. The default axis values are the
integer unit ranges: `1:size(A, d)` for each missing dimension `d`.

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
axis, add a trait using `AxisArrays.axistrait`. Here is the example of
adding a custom Dimensional axis:

```julia
AxisArrays.axistrait(v::MyCustomAxis) = AxisArrays.Dimensional
```

For more advanced indexing, you can define custom methods for
`AxisArrays.axisindexes`.


### Examples

Here is an example with a Dimensional axis representing a time
sequence along rows (it's a FloatRange) and a Categorical axis of
symbols for column headers.

```julia
A = AxisArray(reshape(1:15, 5, 3), Axis{:time}(.1:.1:0.5), Axis{:col}([:a, :b, :c]))
A[Axis{:time}(1:3)]   # equivalent to A[1:3,:]
A[Axis{:time}(Interval(.2,.4))] # restrict the AxisArray along the time axis
A[Interval(0.,.3), [:a, :c]]   # select an interval and two columns
```

""" ->
immutable AxisArray{T,N,D,Ax} <: AbstractArray{T,N}
    data::D  # D <:AbstractArray, enforced in constructor to avoid dispatch bugs (https://github.com/JuliaLang/julia/issues/6383)
    axes::Ax # Ax<:NTuple{N, Axis}, but with specialized Axis{...} types
    AxisArray(data::AbstractArray, axs) = new{T,N,D,Ax}(data, axs)
end
#
_defaultdimname(i) = i == 1 ? (:row) : i == 2 ? (:col) : i == 3 ? (:page) : symbol(:dim_, i)
AxisArray(A::AbstractArray, axs::Axis...) = AxisArray(A, axs)
@generated function AxisArray{T,N,L}(A::AbstractArray{T,N}, axs::NTuple{L,Axis})
    ax = Expr(:tuple)
    Ax = Tuple{axs..., ntuple(i->Axis{_defaultdimname(i+L),UnitRange{Int64}},N-L)...}
    if !isa(axisnames(axs...), Tuple{Vararg{Symbol}})
        return :(throw(ArgumentError("the Axis names must be symbols")))
    end
    for i=1:L
        push!(ax.args, :(axs[$i]))
    end
    for i=L+1:N
        push!(ax.args, :(Axis{_defaultdimname($i)}(1:size(A, $i))))
    end
    quote
        for i = 1:length(axs)
            checkaxis(axs[i].val)
            if length(axs[i].val) != size(A, i)
                throw(ArgumentError("the length of each axis must match the corresponding size of data"))
            end
        end
        if length(unique(axisnames($(ax.args...)))) != N
            throw(ArgumentError("axis names $(axisnames($(ax.args...))) must be unique"))
        end
        $(AxisArray{T,N,A,Ax})(A, $ax)
    end
end
# Simple non-type-stable constructors to specify just the name or axis values
AxisArray(A::AbstractArray) = AxisArray(A, ()) # Disambiguation
AxisArray(A::AbstractArray, names::Symbol...)         = AxisArray(A, ntuple(i->Axis{names[i]}(1:size(A, i)), length(names)))
AxisArray(A::AbstractArray, vects::AbstractVector...) = AxisArray(A, ntuple(i->Axis{_defaultdimname(i)}(vects[i]), length(vects)))

# Axis definitions
@doc """
    axisdim(::AxisArray, ::Axis) -> Int
    axisdim(::AxisArray, ::Type{Axis}) -> Int

Given an AxisArray and an Axis, return the integer dimension of
the Axis within the array.
""" ->
axisdim(A::AxisArray, ax::Axis) = axisdim(A, typeof(ax))
@generated function axisdim{T<:Axis}(A::AxisArray, ax::Type{T})
    dim = axisdim(A, T)
    :($dim)
end
# The actual computation is done in the type domain, which is a little tricky
# due to type invariance.
axisdim{T,N,D,Ax,name,S}(A::Type{AxisArray{T,N,D,Ax}}, ::Type{Axis{name,S}}) = axisdim(A, Axis{name})
function axisdim{T,N,D,Ax,name}(::Type{AxisArray{T,N,D,Ax}}, ::Type{Axis{name}})
    isa(name, Int) && return name <= N ? name : error("axis $name greater than array dimensionality $N")
    names = axisnames(Ax...)
    idx = findfirst(names, name)
    idx == 0 && error("axis $name not found in array axes $names")
    idx
end

# Base definitions that aren't provided by AbstractArray
Base.size(A::AxisArray) = size(A.data)
Base.size(A::AxisArray, Ax::Axis) = size(A.data, axisdim(A, Ax))
Base.size{Ax<:Axis}(A::AxisArray, ::Type{Ax}) = size(A.data, axisdim(A, Ax))
Base.linearindexing(A::AxisArray) = Base.linearindexing(A.data)
Base.convert{T,N}(::Type{Array{T,N}}, A::AxisArray{T,N}) = convert(Array{T,N}, A.data)
# Similar is tricky. If we're just changing the element type, it can stay as an
# AxisArray. But if we're changing dimensions, there's no way it can know how
# to keep track of the axes, so just punt and return a regular old Array.
# TODO: would it feel more consistent to return an AxisArray without any axes?
Base.similar{T}(A::AxisArray{T})          = (d = similar(A.data, T); AxisArray(d, A.axes))
Base.similar{T}(A::AxisArray{T}, S)       = (d = similar(A.data, S); AxisArray(d, A.axes))
Base.similar{T}(A::AxisArray{T}, S, ::Tuple{}) = (d = similar(A.data, S); AxisArray(d, A.axes))
Base.similar{T}(A::AxisArray{T}, dims::Int)         = similar(A, T, (dims,))
Base.similar{T}(A::AxisArray{T}, dims::Int...)      = similar(A, T, dims)
Base.similar{T}(A::AxisArray{T}, dims::Tuple{Vararg{Int}})    = similar(A, T, dims)
Base.similar{T}(A::AxisArray{T}, S, dims::Int...)   = similar(A.data, S, dims)
Base.similar{T}(A::AxisArray{T}, S, dims::Tuple{Vararg{Int}}) = similar(A.data, S, dims)
# If, however, we pass Axis objects containing the new axis for that dimension,
# we can return a similar AxisArray with an appropriately modified size
Base.similar{T}(A::AxisArray{T}, axs::Axis...) = similar(A, T, axs)
Base.similar{T}(A::AxisArray{T}, S, axs::Axis...) = similar(A, S, axs)
@generated function Base.similar{T,N}(A::AxisArray{T,N}, S, axs::Tuple{Vararg{Axis}})
    sz = Expr(:tuple)
    ax = Expr(:tuple)
    for d=1:N
        push!(sz.args, :(size(A, Axis{$d})))
        push!(ax.args, :(axes(A, Axis{$d})))
    end
    to_delete = Int[]
    for (i,a) in enumerate(axs)
        d = axisdim(A, a)
        axistype(a) <: Tuple{} && push!(to_delete, d)
        sz.args[d] = :(length(axs[$i].val))
        ax.args[d] = :(axs[$i])
    end
    sort!(to_delete)
    deleteat!(sz.args, to_delete)
    deleteat!(ax.args, to_delete)
    quote
        d = similar(A.data, S, $sz)
        AxisArray(d, $ax)
    end
end

# Custom methods specific to AxisArrays
@doc """
    axisnames(A::AxisArray)           -> (Symbol...)
    axisnames(::Type{AxisArray{...}}) -> (Symbol...)
    axisnames(ax::Axis...)            -> (Symbol...)
    axisnames(::Type{Axis{...}}...)   -> (Symbol...)

Returns the axis names of an AxisArray or list of Axises as a tuple of symbols.
""" ->
axisnames{T,N,D,Ax}(::AxisArray{T,N,D,Ax})       = axisnames(Ax...)
axisnames{T,N,D,Ax}(::Type{AxisArray{T,N,D,Ax}}) = axisnames(Ax...)
axisnames() = ()
axisnames{name  }(::Axis{name},         B::Axis...) = tuple(name, axisnames(B...)...)
axisnames{name  }(::Type{Axis{name}},   B::Type...) = tuple(name, axisnames(B...)...)
axisnames{name,T}(::Type{Axis{name,T}}, B::Type...) = tuple(name, axisnames(B...)...)

@doc """
    axisvalues(A::AxisArray)           -> (AbstractVector...)
    axisvalues(ax::Axis...)            -> (AbstractVector...)

Returns the axis values of an AxisArray or list of Axises as a tuple of vectors.
""" ->
axisvalues(A::AxisArray) = axisvalues(A.axes...)
axisvalues() = ()
axisvalues(ax::Axis, axs::Axis...) = tuple(ax.val, axisvalues(axs...)...)

@doc """
    axes(A::AxisArray) -> (Axis...)
    axes(A::AxisArray, ax::Axis) -> Axis
    axes(A::AxisArray, dim::Int) -> Axis

Returns the tuple of axis vectors for an AxisArray. If an specific `Axis` is
specified, then only that axis vector is returned.  Note that when extracting a
single axis vector, `axes(A, Axis{1})`) is type-stable and will perform better
than `axes(A)[1]`.
""" ->
axes(A::AxisArray) = A.axes
axes(A::AxisArray, dim::Int) = A.axes[dim]
axes(A::AxisArray, ax::Axis) = axes(A, typeof(ax))
@generated function axes{T<:Axis}(A::AxisArray, ax::Type{T})
    dim = axisdim(A, T)
    :(A.axes[$dim])
end

### Axis traits ###
abstract AxisTrait
immutable Dimensional <: AxisTrait end
immutable Categorical <: AxisTrait end
immutable Unsupported <: AxisTrait end

axistrait(::Any) = Unsupported
axistrait{T<:Union(Number, Dates.AbstractTime)}(::AbstractVector{T}) = Dimensional
axistrait{T<:Union(Symbol, AbstractString)}(::AbstractVector{T}) = Categorical

checkaxis(ax) = checkaxis(axistrait(ax), ax)
checkaxis(::Type{Unsupported}, ax) = nothing # TODO: warn or error?
# Dimensional axes must be monotonically increasing
checkaxis{T}(::Type{Dimensional}, ax::Range{T}) = step(ax) > zero(T) || throw(ArgumentError("Dimensional axes must be monotonically increasing"))
checkaxis(::Type{Dimensional}, ax) = issorted(ax) || throw(ArgumentError("Dimensional axes must be monotonically increasing"))
# Categorical axes must simply be unique
function checkaxis(::Type{Categorical}, ax)
    seen = Set{eltype(ax)}()
    for elt in ax
        if elt in seen
            throw(ArgumentError("Categorical axes must be unique"))
        end
        push!(seen, elt)
    end
end
