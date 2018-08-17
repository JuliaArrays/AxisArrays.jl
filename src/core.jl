# Core types and definitions

using Base: @pure

const Symbols = Tuple{Symbol,Vararg{Symbol}}

# We absolutely need ntuple of small numbers (ndims) to inline, but it might not in Base. Do it here:
@inline function ntuple(f::F, n::Integer) where F
    t = n == 0  ? () :
        n == 1  ? (f(1),) :
        n == 2  ? (f(1), f(2)) :
        n == 3  ? (f(1), f(2), f(3)) :
        n == 4  ? (f(1), f(2), f(3), f(4)) :
        n == 5  ? (f(1), f(2), f(3), f(4), f(5)) :
        n == 6  ? (f(1), f(2), f(3), f(4), f(5), f(6)) :
        n == 7  ? (f(1), f(2), f(3), f(4), f(5), f(6), f(7)) :
        n == 8  ? (f(1), f(2), f(3), f(4), f(5), f(6), f(7), f(8)) :
        n == 9  ? (f(1), f(2), f(3), f(4), f(5), f(6), f(7), f(8), f(9)) :
        n == 10 ? (f(1), f(2), f(3), f(4), f(5), f(6), f(7), f(8), f(9), f(10)) :
        Base._ntuple(f, n)
    return t
end

"""
Type-stable axis-specific indexing and identification with a
parametric type.

### Type parameters

```julia
struct Axis{name,T}
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

"""
struct Axis{name,T}
    val::T
end
# Constructed exclusively through Axis{:symbol}(...) or Axis{1}(...)
Axis{name}(I::T=()) where {name,T} = Axis{name,T}(I)
Base.:(==)(A::Axis{name}, B::Axis{name}) where {name} = A.val == B.val
Base.hash(A::Axis{name}, hx::UInt) where {name} = hash(A.val, hash(name, hx))
axistype(::Axis{name,T}) where {name,T} = T
axistype(::Type{Axis{name,T}}) where {name,T} = T
# Pass indexing and related functions straight through to the wrapped value
# TODO: should Axis be an AbstractArray? AbstractArray{T,0} for scalar T?
Base.getindex(A::Axis, i...) = A.val[i...]
Base.eltype(::Type{Axis{name,T}}) where {name,T} = eltype(T)
Base.size(A::Axis) = size(A.val)
VERSION < v"0.7.0" && (Base.endof(A::Axis) = length(A))
Base.lastindex(A::Axis) = length(A)
Base.axes(A::Axis) = Base.axes(A.val)
Base.axes(A::Axis, d) = Base.axes(A.val, d)
Base.length(A::Axis) = length(A.val)
(A::Axis{name})(i) where {name} = Axis{name}(i)
Base.convert(::Type{Axis{name,T}}, ax::Axis{name,T}) where {name,T} = ax
Base.convert(::Type{Axis{name,T}}, ax::Axis{name}) where {name,T} = Axis{name}(convert(T, ax.val))
Base.iterate(a::Axis) = (a, nothing)
Base.iterate(::Axis, ::Any) = nothing
Base.iterate(::Type{T}) where {T<:Axis} = (T, nothing)
Base.iterate(::Type{T}, ::Any) where {T<:Axis} = nothing

"""
An AxisArray is an AbstractArray that wraps another AbstractArray and
adds axis names and values to each array dimension. AxisArrays can be indexed
by using the named axes as an alternative to positional indexing by
dimension. Other advanced indexing along axis values are also provided.

### Type parameters

The AxisArray contains several type parameters:

```julia
struct AxisArray{T,N,D,Ax} <: AbstractArray{T,N}
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
:dim_5, ...)`. The default axis values are `Base.axes(A, d)` for each
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
axis, add a trait using [`AxisArrays.axistrait`](@ref).

For more advanced indexing, you can define custom methods for
[`AxisArrays.axisindexes`](@ref).

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

"""
struct AxisArray{T,N,D,Ax} <: AbstractArray{T,N}
    data::D  # D <:AbstractArray, enforced in constructor to avoid dispatch bugs (https://github.com/JuliaLang/julia/issues/6383)
    axes::Ax # Ax<:NTuple{N, Axis}, but with specialized Axis{...} types
    AxisArray{T,N,D,Ax}(data::AbstractArray{T,N}, axs::Tuple{Vararg{Axis,N}}) where {T,N,D,Ax} = new{T,N,D,Ax}(data, axs)
end

# Helper functions: Default axis names (if not provided)
@inline _defaultdimname(i) = i == 1 ? (:row) : i == 2 ? (:col) : i == 3 ? (:page) : i == 4 ? :dim_4 : Symbol(:dim_, i)

_merge(::Tuple{}, ::Tuple{}) = ()
_merge(array_axes::Tuple{}, given_axes) = given_axes
_merge(array_axes, given_axes::Tuple{}) = array_axes
@inline _merge(array_axes, given_axes) = (given_axes[1], _merge(tail(array_axes), tail(given_axes))...)

@inline _default_axis(ax, i) = Axis{_defaultdimname(i)}(ax)
_default_axis(ax::Axis, i) = ax

"""
    default_axes(A::AbstractArray)
    default_axes(A::AbstractArray, axs)

Return a tuple of Axis objects that appropriately index into the array A.

The optional second argument can take a tuple of vectors or axes, which will be
wrapped with the appropriate axis name.
"""
@inline function default_axes(A::AbstractArray, given_axs=())
    axs = _merge(Base.axes(A), given_axs)
    ntuple(i->(Base.@_inline_meta; _default_axis(axs[i], i)), length(axs))
end

# Axis consistency checks — ensure sizes match and the names are unique
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

# The primary AxisArray constructors — specify an array to wrap and the axes
AxisArray(A::AbstractArray, vects::Union{AbstractVector, Axis}...) = AxisArray(A, vects)
AxisArray(A::AbstractArray, vects::Tuple{Vararg{Union{AbstractVector, Axis}}}) = AxisArray(A, default_axes(A, vects))
function AxisArray(A::AbstractArray, vects::Tuple{Vararg{Axis}})
    length(vects) > ndims(A) && throw(ArgumentError("too many axes ($(length(vects))) given for a $(ndims(A))-dimensional array"))
    AxisArray(A, default_axes(A, vects))
end
function AxisArray(A::D, axs::Ax) where {T,N,D<:AbstractArray{T,N},Ax<:NTuple{N,Axis}}
    checksizes(axs, _size(A)) || throw(ArgumentError("the length of each axis must match the corresponding size of data"))
    checknames(axisnames(axs...)...)
    AxisArray{T,N,D,Ax}(A, axs)
end

# Simple non-type-stable constructors to specify names as symbols
AxisArray(A::AbstractArray) = AxisArray(A, ()) # Disambiguation
AxisArray(A::AbstractArray, names::Symbol...)         = (inds = Base.axes(A); AxisArray(A, ntuple(i->Axis{names[i]}(inds[i]), length(names))))
function AxisArray(A::AbstractArray{T,N}, names::NTuple{N,Symbol}, steps::NTuple{N,Number}, offsets::NTuple{N,Number}=map(zero, steps)) where {T,N}
    axs = ntuple(i->Axis{names[i]}(range(offsets[i], step=steps[i], length=size(A,i))), N)
    AxisArray(A, axs...)
end

AxisArray(A::AxisArray) = A
AxisArray(A::AxisArray, ax::Vararg{Axis, N}) where N =
    AxisArray(A.data, ax..., last(Base.IteratorsMD.split(axes(A), Val(N)))...)
AxisArray(A::AxisArray, ax::NTuple{N, Axis}) where N =
    AxisArray(A.data, ax..., last(Base.IteratorsMD.split(axes(A), Val(N)))...)

# Traits
struct HasAxes{B} end
HasAxes(::Type{<:AxisArray}) = HasAxes{true}()
HasAxes(::Type{<:AbstractArray}) = HasAxes{false}()
HasAxes(::A) where A<:AbstractArray = HasAxes(A)

"""
    axisnames(A::AxisArray)           -> (Symbol...)
    axisnames(::Type{AxisArray{...}}) -> (Symbol...)
    axisnames(ax::Axis...)            -> (Symbol...)
    axisnames(::Type{Axis{...}}...)   -> (Symbol...)

Returns the axis names of an AxisArray or list of Axises as a tuple of Symbols.
"""
axisnames(::AxisArray{T,N,D,Ax}) where {T,N,D,Ax}       = _axisnames(Ax)
axisnames(::Type{AxisArray{T,N,D,Ax}}) where {T,N,D,Ax} = _axisnames(Ax)
axisnames(::Type{Ax}) where {Ax<:Tuple{Vararg{Axis}}}   = _axisnames(Ax)
@pure _axisnames(Ax) = axisnames(Ax.parameters...)
axisnames() = ()
@inline axisnames(::Axis{name},         B::Axis...) where {name} = tuple(name, axisnames(B...)...)
@inline axisnames(::Type{<:Axis{name}}, B::Type...) where {name} = tuple(name, axisnames(B...)...)

axisname(::Union{Type{<:Axis{name}},Axis{name}}) where {name} = name

# Axis definitions
"""
    axisdim(::AxisArray, ::Axis) -> Int
    axisdim(::AxisArray, ::Type{Axis}) -> Int

Given an AxisArray and an Axis, return the integer dimension of
the Axis within the array.
"""
axisdim(A::AxisArray, ax::Axis) = axisdim(A, typeof(ax))
@generated function axisdim(A::AxisArray, ax::Type{Ax}) where Ax<:Axis
    dim = axisdim(A, Ax)
    :($dim)
end
# The actual computation is done in the type domain, which is a little tricky
# due to type invariance.
function axisdim(::Type{AxisArray{T,N,D,Ax}}, ::Type{<:Axis{name,S} where S}) where {T,N,D,Ax,name}
    isa(name, Int) && return name <= N ? name : error("axis $name greater than array dimensionality $N")
    names = axisnames(Ax)
    idx = Compat.findfirst(isequal(name), names)
    idx === nothing && error("axis $name not found in array axes $names")
    idx
end

# Base definitions that aren't provided by AbstractArray
@inline Base.size(A::AxisArray) = size(A.data)
@inline Base.size(A::AxisArray, Ax::Axis) = size(A.data, axisdim(A, Ax))
@inline Base.size(A::AxisArray, ::Type{Ax}) where {Ax<:Axis} = size(A.data, axisdim(A, Ax))
@inline Base.axes(A::AxisArray) = Base.axes(A.data)
@inline Base.axes(A::AxisArray, Ax::Axis) = Base.axes(A.data, axisdim(A, Ax))
@inline Base.axes(A::AxisArray, ::Type{Ax}) where {Ax<:Axis} = Base.axes(A.data, axisdim(A, Ax))
Base.convert(::Type{Array{T,N}}, A::AxisArray{T,N}) where {T,N} = convert(Array{T,N}, A.data)
Base.parent(A::AxisArray) = A.data
# Similar is tricky. If we're just changing the element type, it can stay as an
# AxisArray. But if we're changing dimensions, there's no way it can know how
# to keep track of the axes, so just punt and return a regular old Array.
# TODO: would it feel more consistent to return an AxisArray without any axes?
Base.similar(A::AxisArray, ::Type{S}) where {S} = (d = similar(A.data, S); AxisArray(d, A.axes))
Base.similar(A::AxisArray, ::Type{S}, dims::Dims{N}) where {S,N} = similar(A.data, S, dims)
# If, however, we pass Axis objects containing the new axis for that dimension,
# we can return a similar AxisArray with an appropriately modified size
Base.similar(A::AxisArray{T}, ax1::Axis, axs::Axis...) where {T} = similar(A, T, (ax1, axs...))
Base.similar(A::AxisArray, ::Type{S}, ax1::Axis, axs::Axis...) where {S} = similar(A, S, (ax1, axs...))
@generated function Base.similar(A::AxisArray{T,N}, ::Type{S}, axs::Tuple{Axis,Vararg{Axis}}) where {T,S,N}
    inds = Expr(:tuple)
    ax = Expr(:tuple)
    for d=1:N
        push!(inds.args, :(Base.axes(A, Axis{$d})))
        push!(ax.args, :(axes(A, Axis{$d})))
    end
    to_delete = Int[]
    for i=1:length(axs.parameters)
        a = axs.parameters[i]
        d = axisdim(A, a)
        axistype(a) <: Tuple{} && push!(to_delete, d)
        inds.args[d] = :(Base.axes(axs[$i].val, 1))
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
const AxisUnitRange{T,N,D<:AbstractUnitRange,Ax} = AxisArray{T,N,D,Ax}
Base.similar(A::AxisArray{T}, ax1::AxisUnitRange, axs::AxisUnitRange...) where {T} = similar(A, T, (ax1, axs...))
Base.similar(A::AxisArray, ::Type{S}, ax1::AxisUnitRange, axs::AxisUnitRange...) where {S} = similar(A, S, (ax1, axs...))
Base.similar(A::AxisArray, ::Type{S}, axs::Tuple{AxisUnitRange,Vararg{AxisUnitRange}}) where {S} = similar(A, S, map(x->x.axes[1], axs))
# These methods allow us to preserve the AxisArray under reductions
# Note that we only extend the following two methods, and then have it
# dispatch to package-local `reduced_indices` and `reduced_indices0`
# methods. This avoids a whole slew of ambiguities.
Base.reduced_indices(A::AxisArray, region)  = map(ax->AxisArray(Base.axes(ax.val, 1), ax), reduced_indices(axes(A), region))
Base.reduced_indices0(A::AxisArray, region) = map(ax->AxisArray(Base.axes(ax.val, 1), ax), reduced_indices0(axes(A), region))

reduced_indices(axs::Tuple{Vararg{Axis}}, ::Tuple{})  = axs
reduced_indices0(axs::Tuple{Vararg{Axis}}, ::Tuple{}) = axs
reduced_indices(axs::Tuple{Vararg{Axis}}, region::Integer) =
    reduced_indices(axs, (region,))
reduced_indices0(axs::Tuple{Vararg{Axis}}, region::Integer) =
    reduced_indices0(axs, (region,))

reduced_indices(axs::Tuple{Vararg{Axis,N}}, region::Dims) where {N} =
    map((ax,d)->d∈region ? reduced_axis(ax) : ax, axs, ntuple(identity, N))
reduced_indices0(axs::Tuple{Vararg{Axis,N}}, region::Dims) where {N} =
    map((ax,d)->d∈region ? reduced_axis0(ax) : ax, axs, ntuple(identity, N))

@inline reduced_indices(axs::Tuple{Vararg{Axis}}, region::Type{<:Axis}) =
    _reduced_indices(reduced_axis, (), region, axs...)
@inline reduced_indices0(axs::Tuple{Vararg{Axis}}, region::Type{<:Axis}) =
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

@pure samesym(::Type{Axis{n1}}, ::Type{Axis{n2}}) where {n1,n2} = Val(n1==n2)
samesym(::Type{<:Axis{n1}}, ::Type{<:Axis{n2}}) where {n1,n2} = samesym(Axis{n1},Axis{n2})
samesym(::Type{Axis{n1}}, ::Axis{n2}) where {n1,n2} = samesym(Axis{n1}, Axis{n2})
samesym(::Axis{n1}, ::Type{Axis{n2}}) where {n1,n2} = samesym(Axis{n1}, Axis{n2})
samesym(::Axis{n1}, ::Axis{n2}) where {n1,n2} = samesym(Axis{n1}, Axis{n2})

@inline _reduced_indices(f, out, chosen::Type{<:Axis}, ax::Axis, axs...) =
    __reduced_indices(f, out, samesym(chosen, ax), chosen, ax, axs)
@inline _reduced_indices(f, out, chosen::Axis, ax::Axis, axs...) =
    __reduced_indices(f, out, samesym(chosen, ax), chosen, ax, axs)
_reduced_indices(f, out, chosen) = out

@inline __reduced_indices(f, out, ::Val{true}, chosen, ax, axs) =
    _reduced_indices(f, (out..., f(ax)), chosen, axs...)
@inline __reduced_indices(f, out, ::Val{false}, chosen, ax, axs) =
    _reduced_indices(f, (out..., ax), chosen, axs...)

reduced_axis( ax::Axis{name,<:AbstractArray{T}}) where {name,T<:Number} = ax(oftype(ax.val, Base.OneTo(1)))
reduced_axis0(ax::Axis{name,<:AbstractArray{T}}) where {name,T<:Number} = ax(oftype(ax.val, length(ax.val) == 0 ? Base.OneTo(0) : Base.OneTo(1)))

reduced_axis( ax) = ax(Base.OneTo(1))
reduced_axis0(ax) = ax(length(ax.val) == 0 ? Base.OneTo(0) : Base.OneTo(1))


function Base.permutedims(A::AxisArray, perm)
    p = permutation(perm, axisnames(A))
    AxisArray(permutedims(A.data, p), axes(A)[[p...]])
end

Base.transpose(A::AxisArray{T,2}) where {T}  = AxisArray(transpose(A.data), A.axes[2], A.axes[1])
Base.adjoint(A::AxisArray{T,2}) where {T} = AxisArray(adjoint(A.data), A.axes[2], A.axes[1])
Base.transpose(A::AxisArray{T,1}) where {T}  = AxisArray(transpose(A.data), Axis{:transpose}(Base.OneTo(1)), A.axes[1])
Base.adjoint(A::AxisArray{T,1}) where {T} = AxisArray(adjoint(A.data), Axis{:transpose}(Base.OneTo(1)), A.axes[1])

Base.map!(f::F, A::AxisArray) where {F} = (map!(f, A.data); A)
Base.map(f, A::AxisArray) = AxisArray(map(f, A.data), A.axes...)

function Base.map!(f::F, dest::AxisArray{T,N,D,Ax}, As::AxisArray{T,N,D,Ax}...) where {F,T,N,D,Ax<:Tuple{Vararg{Axis}}}
    matchingdims((dest, As...)) || error("All axes must be identically-valued")
    data = map(a -> a.data, As)
    map!(f, dest.data, data...)
    return dest
end

function Base.map(f, As::AxisArray{T,N,D,Ax}...) where {T,N,D,Ax<:Tuple{Vararg{Axis}}}
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
    li = eachindex(from)
    d = Dict(from[i]=>i for i in li)
    covered = Array(falses(length(li)))
    ind = Array{Int}(undef, max(n, nf))
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

@inline Base.dropdims(A::AxisArray; dims) = _dropdims(A, dims)

function _dropdims(A::AxisArray, dims)
    keepdims = setdiff(1:ndims(A), dims)
    AxisArray(dropdims(A.data; dims=dims), axes(A)[keepdims])
end
# This version attempts to be type-stable
function _dropdims(A::AxisArray, ::Type{Ax}) where {Ax<:Axis}
    dim = axisdim(A, Ax)
    AxisArray(dropdims(A.data; dims=dim), dropax(Ax, axes(A)...))
end

@inline dropax(ax, ax1, axs...) = (ax1, dropax(ax, axs...)...)
@inline dropax(ax::Axis{name}, ax1::Axis{name}, axs...) where {name} = dropax(ax, axs...)
@inline dropax(ax::Type{<:Axis{name}}, ax1::Axis{name}, axs...) where {name} = dropax(ax, axs...)
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
_summary(io, A::AxisArray{T,N}) where {T,N} = println(io, "$N-dimensional AxisArray{$T,$N,...} with axes:")

function Base.summary(A::AxisArray)
    io = IOBuffer()
    summaryio(io, A)
    String(take!(io))
end

# Custom methods specific to AxisArrays
"""
    axisvalues(A::AxisArray)           -> (AbstractVector...)
    axisvalues(ax::Axis...)            -> (AbstractVector...)

Returns the axis values of an AxisArray or list of Axises as a tuple of vectors.
"""
axisvalues(A::AxisArray) = axisvalues(A.axes...)
axisvalues() = ()
axisvalues(ax::Axis, axs::Axis...) = tuple(ax.val, axisvalues(axs...)...)

"""
    axes(A::AxisArray) -> (Axis...)
    axes(A::AxisArray, ax::Axis) -> Axis
    axes(A::AxisArray, dim::Int) -> Axis

Returns the tuple of axis vectors for an AxisArray. If an specific `Axis` is
specified, then only that axis vector is returned.  Note that when extracting a
single axis vector, `axes(A, Axis{1})`) is type-stable and will perform better
than `axes(A)[1]`.

For an AbstractArray without `Axis` information, `axes` returns the
default axes, i.e., those that would be produced by `AxisArray(A)`.
"""
axes(A::AxisArray) = A.axes
axes(A::AxisArray, dim::Int) = A.axes[dim]
axes(A::AxisArray, ax::Axis) = axes(A, typeof(ax))
@generated function axes(A::AxisArray, ax::Type{T}) where T<:Axis
    dim = axisdim(A, T)
    :(A.axes[$dim])
end
axes(A::AbstractArray) = default_axes(A)
axes(A::AbstractArray, dim::Int) = default_axes(A)[dim]

"""
    axisparams(::AxisArray) -> Vararg{::Type{Axis}}
    axisparams(::Type{AxisArray}) -> Vararg{::Type{Axis}}

Returns the axis parameters for an AxisArray.
"""
axisparams(::AxisArray{T,N,D,Ax}) where {T,N,D,Ax} = (Ax.parameters...,)
axisparams(::Type{AxisArray{T,N,D,Ax}}) where {T,N,D,Ax} = (Ax.parameters...,)

### Axis traits ###
abstract type AxisTrait end
struct Dimensional <: AxisTrait end
struct Categorical <: AxisTrait end
struct Unsupported <: AxisTrait end

"""
    axistrait(ax::Axis) -> Type{<:AxisTrait}
    axistrait{T}(::Type{T}) -> Type{<:AxisTrait}

Returns the indexing type of an `Axis`, any subtype of `AxisTrait`.
The default is `Unsupported`, meaning there is no special indexing behaviour for this axis
and indexes into this axis are passed directly to the underlying array.

Two main types of axes supported by default are `Categorical` and `Dimensional`; see
[Indexing](@ref) for more information on these types.

User-defined axis types can be added along with custom indexing behaviors by defining new
methods of this function. Here is the example of adding a custom Dimensional axis:

```julia
AxisArrays.axistrait(::Type{MyCustomAxis}) = AxisArrays.Dimensional
```
"""
axistrait(::T) where {T} = axistrait(T)
axistrait(::Type{T}) where {T} = Unsupported
axistrait(::Type{Axis{name,T}}) where {name,T} = axistrait(T)
axistrait(::Type{T}) where {T<:AbstractVector} = _axistrait_el(eltype(T))
_axistrait_el(::Type{<:Union{Number, Dates.AbstractTime}}) = Dimensional
_axistrait_el(::Type{<:Union{Symbol, AbstractString}}) = Categorical
_axistrait_el(::Type{T}) where {T} = Categorical

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

_length(A::AbstractArray) = length(eachindex(A))
_length(A) = length(A)
_size(A::AbstractArray) = map(length, Base.axes(A))
_size(A) = size(A)
_size(A::AbstractArray, d) = length(Base.axes(A, d))
_size(A, d) = size(A, d)
