# Core types and definitions

if VERSION < v"0.5.0-dev"
    macro pure(ex)
        esc(ex)
    end
else
    using Base: @pure
end

const Symbols = Tuple{Symbol,Vararg{Symbol}}

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

* `name` : the axis name Symbol or integer dimension
* `I` : the indexer, any indexing type that the axis supports

### Examples

Here is an example with a Dimensional axis representing a time
sequence along rows and a Categorical axis of Symbols for column
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
(::Type{Axis{name}}){name,T}(I::T=()) = Axis{name,T}(I)
Base.:(==){name}(A::Axis{name}, B::Axis{name}) = A.val == B.val
Base.hash{name}(A::Axis{name}, hx::UInt) = hash(A.val, hash(name, hx))
axistype{name,T}(::Axis{name,T}) = T
axistype{name,T}(::Type{Axis{name,T}}) = T
# Pass indexing and related functions straight through to the wrapped value
# TODO: should Axis be an AbstractArray? AbstractArray{T,0} for scalar T?
Base.getindex(A::Axis, i...) = A.val[i...]
Base.eltype{_,T}(::Type{Axis{_,T}}) = eltype(T)
Base.size(A::Axis) = size(A.val)
Base.endof(A::Axis) = length(A)
Base.indices(A::Axis) = indices(A.val)
Base.indices(A::Axis, d) = indices(A.val, d)
Base.length(A::Axis) = length(A.val)
(A::Axis{name}){name}(i) = Axis{name}(i)
Base.convert{name,T}(::Type{Axis{name,T}}, ax::Axis{name,T}) = ax
Base.convert{name,T}(::Type{Axis{name,T}}, ax::Axis{name}) = Axis{name}(convert(T, ax.val))

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
AxisArray(A::AbstractArray, (names...,), (steps...,), [(offsets...,)])
```

### Arguments

* `A::AbstractArray` : the wrapped array data
* `axes` or `names` or `vectors` : dimensional information for the wrapped array

The dimensional information may be passed in one of three ways and is
entirely optional. When the axis name or value is missing for a
dimension, a default is substituted. The default axis names for
dimensions `(1, 2, 3, 4, 5, ...)` are `(:row, :col, :page, :dim_4,
:dim_5, ...)`. The default axis values are `indices(A, d)` for each
missing dimension `d`.

### Indexing

Indexing returns a view into the original data. The returned view is a
new AxisArray that wraps a SubArray. Indexing should be type
stable. Use `Axis{axisname}(idx)` to index based on a specific
axis. `axisname` is a Symbol specifying the axis to index/slice, and
`idx` is a normal indexing object (`Int`, `Array{Int,1}`, etc.) or a
custom indexing type for that particular type of axis.

Two main types of axes supported by default include:

* Categorical axis -- These are vectors of labels, normally Symbols or
  strings. Elements or slices can be indexed by elements or vectors
  of elements.

* Dimensional axis -- These are sorted vectors or iterators that can
  be indexed by `ClosedInterval()`. These are commonly used for sequences of
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
Symbols for column headers.

```julia
A = AxisArray(reshape(1:15, 5, 3), Axis{:time}(.1:.1:0.5), Axis{:col}([:a, :b, :c]))
A[Axis{:time}(1:3)]   # equivalent to A[1:3,:]
A[Axis{:time}(ClosedInterval(.2,.4))] # restrict the AxisArray along the time axis
A[ClosedInterval(0.,.3), [:a, :c]]   # select an interval and two columns
```

""" ->
immutable AxisArray{T,N,D,Ax} <: AbstractArray{T,N}
    data::D  # D <:AbstractArray, enforced in constructor to avoid dispatch bugs (https://github.com/JuliaLang/julia/issues/6383)
    axes::Ax # Ax<:NTuple{N, Axis}, but with specialized Axis{...} types
    (::Type{AxisArray{T,N,D,Ax}}){T,N,D,Ax}(data::AbstractArray{T,N}, axs::Tuple{Vararg{Axis,N}}) = new{T,N,D,Ax}(data, axs)
end
#
_defaultdimname(i) = i == 1 ? (:row) : i == 2 ? (:col) : i == 3 ? (:page) : Symbol(:dim_, i)

default_axes(A::AbstractArray) = _default_axes(A, indices(A), ())
_default_axes{T,N}(A::AbstractArray{T,N}, inds, axs::NTuple{N,Axis}) = axs
@inline _default_axes{T,N,M}(A::AbstractArray{T,N}, inds, axs::NTuple{M,Axis}) =
    _default_axes(A, inds, (axs..., _nextaxistype(A, axs)(inds[M+1])))
# Why doesn't @pure work here?
@generated function _nextaxistype{T,M}(A::AbstractArray{T}, axs::NTuple{M,Axis})
    name = _defaultdimname(M+1)
    :(Axis{$(Expr(:quote, name))})
end

AxisArray(A::AbstractArray, axs::Axis...) = AxisArray(A, axs)
function AxisArray{T,N}(A::AbstractArray{T,N}, axs::NTuple{N,Axis})
    checksizes(axs, _size(A)) || throw(ArgumentError("the length of each axis must match the corresponding size of data"))
    checknames(axisnames(axs...)...)
    AxisArray{T,N,typeof(A),typeof(axs)}(A, axs)
end
function AxisArray{L}(A::AbstractArray, axs::NTuple{L,Axis})
    newaxs = _default_axes(A, indices(A), axs)
    AxisArray(A, newaxs)
end

@inline checksizes(axs, sz) =
    (length(axs[1]) == sz[1]) & checksizes(tail(axs), tail(sz))
checksizes(::Tuple{}, sz) = true

@inline function checknames(name::Symbol, names...)
    matches = false
    for n in names
        matches |= name == n
    end
    matches && throw(ArgumentError("axis name :$name is used more than once"))
    checknames(names...)
end
checknames(name, names...) = throw(ArgumentError("the Axis names must be Symbols"))
checknames() = ()

# Simple non-type-stable constructors to specify just the name or axis values
AxisArray(A::AbstractArray) = AxisArray(A, ()) # Disambiguation
AxisArray(A::AbstractArray, names::Symbol...)         = (inds = indices(A); AxisArray(A, ntuple(i->Axis{names[i]}(inds[i]), length(names))))
AxisArray(A::AbstractArray, vects::AbstractVector...) = AxisArray(A, ntuple(i->Axis{_defaultdimname(i)}(vects[i]), length(vects)))
function AxisArray{T,N}(A::AbstractArray{T,N}, names::NTuple{N,Symbol}, steps::NTuple{N,Number}, offsets::NTuple{N,Number}=map(zero, steps))
    axs = ntuple(i->Axis{names[i]}(range(offsets[i], steps[i], size(A,i))), N)
    AxisArray(A, axs...)
end

# Traits
immutable HasAxes{B} end
HasAxes{A<:AxisArray}(::Type{A}) = HasAxes{true}()
HasAxes{A<:AbstractArray}(::Type{A}) = HasAxes{false}()
HasAxes(A::AbstractArray) = HasAxes(typeof(A))

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
    names = axisnames(Ax)
    idx = findfirst(names, name)
    idx == 0 && error("axis $name not found in array axes $names")
    idx
end

# Base definitions that aren't provided by AbstractArray
@inline Base.size(A::AxisArray) = size(A.data)
@inline Base.size(A::AxisArray, Ax::Axis) = size(A.data, axisdim(A, Ax))
@inline Base.size{Ax<:Axis}(A::AxisArray, ::Type{Ax}) = size(A.data, axisdim(A, Ax))
@inline Base.indices(A::AxisArray) = indices(A.data)
@inline Base.indices(A::AxisArray, Ax::Axis) = indices(A.data, axisdim(A, Ax))
@inline Base.indices{Ax<:Axis}(A::AxisArray, ::Type{Ax}) = indices(A.data, axisdim(A, Ax))
Base.convert{T,N}(::Type{Array{T,N}}, A::AxisArray{T,N}) = convert(Array{T,N}, A.data)
Base.parent(A::AxisArray) = A.data
# Similar is tricky. If we're just changing the element type, it can stay as an
# AxisArray. But if we're changing dimensions, there's no way it can know how
# to keep track of the axes, so just punt and return a regular old Array.
# TODO: would it feel more consistent to return an AxisArray without any axes?
Base.similar{S}(A::AxisArray, ::Type{S})       = (d = similar(A.data, S); AxisArray(d, A.axes))
Base.similar{S,N}(A::AxisArray, ::Type{S}, dims::Dims{N}) = similar(A.data, S, dims)
# If, however, we pass Axis objects containing the new axis for that dimension,
# we can return a similar AxisArray with an appropriately modified size
Base.similar{T}(A::AxisArray{T}, ax1::Axis, axs::Axis...) = similar(A, T, (ax1, axs...))
Base.similar{S}(A::AxisArray, ::Type{S}, ax1::Axis, axs::Axis...) = similar(A, S, (ax1, axs...))
@generated function Base.similar{T,S,N}(A::AxisArray{T,N}, ::Type{S}, axs::Tuple{Axis,Vararg{Axis}})
    inds = Expr(:tuple)
    ax = Expr(:tuple)
    for d=1:N
        push!(inds.args, :(indices(A, Axis{$d})))
        push!(ax.args, :(axes(A, Axis{$d})))
    end
    to_delete = Int[]
    for i=1:length(axs.parameters)
        a = axs.parameters[i]
        d = axisdim(A, a)
        axistype(a) <: Tuple{} && push!(to_delete, d)
        inds.args[d] = :(indices(axs[$i].val, 1))
        ax.args[d] = :(axs[$i])
    end
    sort!(to_delete)
    deleteat!(inds.args, to_delete)
    deleteat!(ax.args, to_delete)
    quote
        d = similar(A.data, S, $inds)
        AxisArray(d, $ax)
    end
end

# These methods allow us to preserve the AxisArray under reductions
# Note that we only extend the following two methods, and then have it
# dispatch to package-local `reduced_indices` and `reduced_indices0`
# methods. This avoids a whole slew of ambiguities.
if VERSION == v"0.5.0"
    Base.reduced_dims(A::AxisArray, region)  = reduced_indices(axes(A), region)
    Base.reduced_dims0(A::AxisArray, region) = reduced_indices0(axes(A), region)
else
    Base.reduced_indices(A::AxisArray, region)  = reduced_indices(axes(A), region)
    Base.reduced_indices0(A::AxisArray, region) = reduced_indices0(axes(A), region)
end

reduced_indices{N}(axs::Tuple{Vararg{Axis,N}}, ::Tuple{})  = axs
reduced_indices0{N}(axs::Tuple{Vararg{Axis,N}}, ::Tuple{}) = axs
reduced_indices{N}(axs::Tuple{Vararg{Axis,N}}, region::Integer) =
    reduced_indices(axs, (region,))
reduced_indices0{N}(axs::Tuple{Vararg{Axis,N}}, region::Integer) =
    reduced_indices0(axs, (region,))

reduced_indices{N}(axs::Tuple{Vararg{Axis,N}}, region::Dims) =
    map((ax,d)->d∈region ? reduced_axis(ax) : ax, axs, ntuple(identity, Val{N}))
reduced_indices0{N}(axs::Tuple{Vararg{Axis,N}}, region::Dims) =
    map((ax,d)->d∈region ? reduced_axis0(ax) : ax, axs, ntuple(identity, Val{N}))

@inline reduced_indices{Ax<:Axis}(axs::Tuple{Vararg{Axis}}, region::Type{Ax}) =
    _reduced_indices(reduced_axis, (), region, axs...)
@inline reduced_indices0{Ax<:Axis}(axs::Tuple{Vararg{Axis}}, region::Type{Ax}) =
    _reduced_indices(reduced_axis0, (), region, axs...)
@inline reduced_indices(axs::Tuple{Vararg{Axis}}, region::Axis) =
    _reduced_indices(reduced_axis, (), region, axs...)
@inline reduced_indices0(axs::Tuple{Vararg{Axis}}, region::Axis) =
    _reduced_indices(reduced_axis0, (), region, axs...)

reduced_indices(axs::Tuple{Vararg{Axis}}, region::Tuple) =
    reduced_indices(reduced_indices(axs, region[1]), tail(region))
reduced_indices(axs::Tuple{Vararg{Axis}}, region::Tuple{Vararg{Axis}}) =
    reduced_indices(reduced_indices(axs, region[1]), tail(region))
reduced_indices0(axs::Tuple{Vararg{Axis}}, region::Tuple) =
    reduced_indices0(reduced_indices0(axs, region[1]), tail(region))
reduced_indices0(axs::Tuple{Vararg{Axis}}, region::Tuple{Vararg{Axis}}) =
    reduced_indices0(reduced_indices0(axs, region[1]), tail(region))

@pure samesym{n1,n2}(::Type{Axis{n1}}, ::Type{Axis{n2}}) = Val{n1==n2}()
samesym{n1,n2,T1,T2}(::Type{Axis{n1,T1}}, ::Type{Axis{n2,T2}}) = samesym(Axis{n1},Axis{n2})
samesym{n1,n2}(::Type{Axis{n1}}, ::Axis{n2}) = samesym(Axis{n1}, Axis{n2})
samesym{n1,n2}(::Axis{n1}, ::Type{Axis{n2}}) = samesym(Axis{n1}, Axis{n2})
samesym{n1,n2}(::Axis{n1}, ::Axis{n2}) = samesym(Axis{n1}, Axis{n2})

@inline _reduced_indices{Ax<:Axis}(f, out, chosen::Type{Ax}, ax::Axis, axs...) =
    __reduced_indices(f, out, samesym(chosen, ax), chosen, ax, axs)
@inline _reduced_indices(f, out, chosen::Axis, ax::Axis, axs...) =
    __reduced_indices(f, out, samesym(chosen, ax), chosen, ax, axs)
_reduced_indices(f, out, chosen) = out

@inline __reduced_indices(f, out, ::Val{true}, chosen, ax, axs) =
    _reduced_indices(f, (out..., f(ax)), chosen, axs...)
@inline __reduced_indices(f, out, ::Val{false}, chosen, ax, axs) =
    _reduced_indices(f, (out..., ax), chosen, axs...)

reduced_axis(ax) = ax(oftype(ax.val, Base.OneTo(1)))
reduced_axis0(ax) = ax(oftype(ax.val, length(ax.val) == 0 ? Base.OneTo(0) : Base.OneTo(1)))


function Base.permutedims(A::AxisArray, perm)
    p = permutation(perm, axisnames(A))
    AxisArray(permutedims(A.data, p), axes(A)[[p...]])
end

Base.transpose{T}(A::AxisArray{T,2})  = AxisArray(transpose(A.data), A.axes[2], A.axes[1])
Base.ctranspose{T}(A::AxisArray{T,2}) = AxisArray(ctranspose(A.data), A.axes[2], A.axes[1])
Base.transpose{T}(A::AxisArray{T,1})  = AxisArray(transpose(A.data), Axis{:transpose}(Base.OneTo(1)), A.axes[1])
Base.ctranspose{T}(A::AxisArray{T,1}) = AxisArray(ctranspose(A.data), Axis{:transpose}(Base.OneTo(1)), A.axes[1])

Base.map!{F}(f::F, A::AxisArray) = (map!(f, A.data); A)
Base.map(f, A::AxisArray) = AxisArray(map(f, A.data), A.axes...)

function Base.map!{F,T,N,D,Ax<:Tuple{Vararg{Axis}}}(f::F, dest::AxisArray{T,N,D,Ax},
                                                  As::AxisArray{T,N,D,Ax}...)
    matchingdims((dest, As...)) || error("All axes must be identically-valued")
    data = map(a -> a.data, As)
    map!(f, dest.data, data...)
    return dest
end

function Base.map{T,N,D,Ax<:Tuple{Vararg{Axis}}}(f, As::AxisArray{T,N,D,Ax}...)
    matchingdims(As) || error("All axes must be identically-valued")
    data = map(a -> a.data, As)
    return AxisArray(map(f, data...), As[1].axes...)
end

permutation(to::Union{AbstractVector{Int},Tuple{Int,Vararg{Int}}}, from::Symbols) = to

"""
    permutation(to, from) -> p

Calculate the permutation of labels in `from` to produce the order in
`to`. Any entries in `to` that are missing in `from` will receive an
index of 0. Any entries in `from` that are missing in `to` will have
their indices appended to the end of the permutation. Consequently,
the length of `p` is equal to the longer of `to` and `from`.
"""
function permutation(to::Symbols, from::Symbols)
    n = length(to)
    nf = length(from)
    li = linearindices(from)
    d = Dict(from[i]=>i for i in li)
    covered = similar(dims->falses(length(li)), li)
    ind = Array{Int}(max(n, nf))
    for (i,toi) in enumerate(to)
        j = get(d, toi, 0)
        ind[i] = j
        if j != 0
            covered[j] = true
        end
    end
    k = n
    for i in li
        if !covered[i]
            d[from[i]] != i && throw(ArgumentError("$(from[i]) is a duplicated argument"))
            k += 1
            k > nf && throw(ArgumentError("no incomplete containment allowed in $to and $from"))
            ind[k] = i
        end
    end
    ind
end

function Base.squeeze(A::AxisArray, dims::Dims)
    keepdims = setdiff(1:ndims(A), dims)
    AxisArray(squeeze(A.data, dims), axes(A)[keepdims])
end
# This version is type-stable
function Base.squeeze{Ax<:Axis}(A::AxisArray, ::Type{Ax})
    dim = axisdim(A, Ax)
    AxisArray(squeeze(A.data, dim), dropax(Ax, axes(A)...))
end

@inline dropax(ax, ax1, axs...) = (ax1, dropax(ax, axs...)...)
@inline dropax{name}(ax::Axis{name}, ax1::Axis{name}, axs...) = dropax(ax, axs...)
@inline dropax{name}(ax::Type{Axis{name}}, ax1::Axis{name}, axs...) = dropax(ax, axs...)
@inline dropax{name,T}(ax::Type{Axis{name,T}}, ax1::Axis{name}, axs...) = dropax(ax, axs...)
dropax(ax) = ()


# A simple display method to include axis information. It might be nice to
# eventually display the axis labels alongside the data array, but that is
# much more difficult.
function summaryio(io::IO, A::AxisArray)
    _summary(io, A)
    for (name, val) in zip(axisnames(A), axisvalues(A))
        print(io, "    :$name, ")
        show(IOContext(io, :limit=>true), val)
        println(io)
    end
    print(io, "And data, a ", summary(A.data))
end
_summary{T,N}(io, A::AxisArray{T,N}) = println(io, "$N-dimensional AxisArray{$T,$N,...} with axes:")

function Base.summary(A::AxisArray)
    io = IOBuffer()
    summaryio(io, A)
    String(io)
end

# Custom methods specific to AxisArrays
@doc """
    axisnames(A::AxisArray)           -> (Symbol...)
    axisnames(::Type{AxisArray{...}}) -> (Symbol...)
    axisnames(ax::Axis...)            -> (Symbol...)
    axisnames(::Type{Axis{...}}...)   -> (Symbol...)

Returns the axis names of an AxisArray or list of Axises as a tuple of Symbols.
""" ->
axisnames{T,N,D,Ax}(::AxisArray{T,N,D,Ax})       = _axisnames(Ax)
axisnames{T,N,D,Ax}(::Type{AxisArray{T,N,D,Ax}}) = _axisnames(Ax)
axisnames{Ax<:Tuple{Vararg{Axis}}}(::Type{Ax})   = _axisnames(Ax)
@pure _axisnames(Ax) = axisnames(Ax.parameters...)
axisnames() = ()
@inline axisnames{name  }(::Axis{name},         B::Axis...) = tuple(name, axisnames(B...)...)
@inline axisnames{name  }(::Type{Axis{name}},   B::Type...) = tuple(name, axisnames(B...)...)
@inline axisnames{name,T}(::Type{Axis{name,T}}, B::Type...) = tuple(name, axisnames(B...)...)

axisname{name,T}(::Type{Axis{name,T}}) = name
axisname{name  }(::Type{Axis{name  }}) = name
axisname(ax::Axis) = axisname(typeof(ax))

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

For an AbstractArray without `Axis` information, `axes` returns the
default axes, i.e., those that would be produced by `AxisArray(A)`.
""" ->
axes(A::AxisArray) = A.axes
axes(A::AxisArray, dim::Int) = A.axes[dim]
axes(A::AxisArray, ax::Axis) = axes(A, typeof(ax))
@generated function axes{T<:Axis}(A::AxisArray, ax::Type{T})
    dim = axisdim(A, T)
    :(A.axes[$dim])
end
axes(A::AbstractArray) = default_axes(A)
axes(A::AbstractArray, dim::Int) = default_axes(A)[dim]

### Axis traits ###
@compat abstract type AxisTrait end
immutable Dimensional <: AxisTrait end
immutable Categorical <: AxisTrait end
immutable Unsupported <: AxisTrait end

axistrait(::Any) = Unsupported
axistrait(ax::Axis) = axistrait(ax.val)
axistrait{T<:Union{Number, Dates.AbstractTime}}(::AbstractVector{T}) = Dimensional
axistrait{T<:Union{Symbol, AbstractString}}(::AbstractVector{T}) = Categorical

checkaxis(ax::Axis) = checkaxis(ax.val)
checkaxis(ax) = checkaxis(axistrait(ax), ax)
checkaxis(::Type{Unsupported}, ax) = nothing # TODO: warn or error?
# Dimensional axes must be monotonically increasing
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

_length(A::AbstractArray) = length(linearindices(A))
_length(A) = length(A)
_size(A::AbstractArray) = map(length, indices(A))
_size(A) = size(A)
_size(A::AbstractArray, d) = length(indices(A, d))
_size(A, d) = size(A, d)
