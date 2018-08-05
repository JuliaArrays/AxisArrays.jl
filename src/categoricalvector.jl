"""
A CategoricalVector is an AbstractVector which is treated as a categorical axis regardless
of the element type. Duplicate values are not allowed but are not filtered out.

A CategoricalVector axis can be indexed with an ClosedInterval, with a value, or with a
vector of values. Use of a CategoricalVector{Tuple} axis allows indexing similar to the
hierarchical index of the Python Pandas package or the R data.table package.

In general, indexing into a CategoricalVector will be much slower than the corresponding
SortedVector or another sorted axis type, as linear search is required.

### Constructors

```julia
CategoricalVector(x::AbstractVector)
```

### Arguments

* `x::AbstractVector` : the wrapped vector

### Examples

```julia
v = CategoricalVector(collect([1; 8; 10:15]))
A = AxisArray(reshape(1:16, 8, 2), v, [:a, :b])
A[Axis{:row}(1), :]
A[Axis{:row}(10), :]
A[Axis{:row}([1, 10]), :]

## Hierarchical index example with three key levels

data = reshape(1.:40., 20, 2)
v = collect(zip([:a, :b, :c][rand(1:3,20)], [:x,:y][rand(1:2,20)], [:x,:y][rand(1:2,20)]))
A = AxisArray(data, CategoricalVector(v), [:a, :b])
A[:b, :]
A[[:a,:c], :]
A[(:a,:x), :]
A[(:a,:x,:x), :]
```
"""
struct CategoricalVector{T, A<:AbstractVector{T}} <: AbstractVector{T}
    data::A
end

Base.getindex(v::CategoricalVector, idx::Int) = v.data[idx]
Base.getindex(v::CategoricalVector, idx::AbstractVector) = CategoricalVector(v.data[idx])

Base.length(v::CategoricalVector) = length(v.data)
Base.size(v::CategoricalVector) = size(v.data)
Base.size(v::CategoricalVector, i) = size(v.data, i)
Base.axes(v::CategoricalVector) = Base.axes(v.data)

axistrait(::Type{CategoricalVector{T,A}}) where {T,A} = Categorical
checkaxis(::CategoricalVector) = nothing


## Add some special indexing for CategoricalVector{Tuple}'s to achieve something like
## Panda's hierarchical indexing

axisindexes(ax::Axis{S,CategoricalVector{T,A}}, idx) where {T<:Tuple,S,A} = axisindexes(ax, (idx,))

function axisindexes(ax::Axis{S,CategoricalVector{T,A}}, idx::Tuple) where {T<:Tuple,S,A}
    collect(filter(ax_idx->_tuple_matches(ax.val[ax_idx], idx), Base.axes(ax.val)...))
end

function _tuple_matches(element::Tuple, idx::Tuple)
    length(idx) <= length(element) || return false

    for (x, y) in zip(element, idx)
        x == y || return false
    end

    return true
end

axisindexes(ax::Axis{S,CategoricalVector{T,A}}, idx::AbstractArray) where {T<:Tuple,S,A} =
    vcat([axisindexes(ax, i) for i in idx]...)
