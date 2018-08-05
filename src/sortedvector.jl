
export SortedVector

"""

A SortedVector is an AbstractVector where the underlying data is
ordered (monotonically increasing).

Indexing that would unsort the data is prohibited. A SortedVector is a
Dimensional axis, and no checking is done to ensure that the data is
sorted. Duplicate values are allowed.

A SortedVector axis can be indexed with an ClosedInterval, with a value, or
with a vector of values. Use of a SortedVector{Tuple} axis allows
indexing similar to the hierarchical index of the Python Pandas
package or the R data.table package.

### Constructors

```julia
SortedVector(x::AbstractVector)
```

### Keyword Arguments

* `x::AbstractVector` : the wrapped vector

### Examples

```julia
v = SortedVector(collect([1.; 10.; 10:15.]))
A = AxisArray(reshape(1:16, 8, 2), v, [:a, :b])
A[ClosedInterval(8.,12.), :]
A[1., :]
A[10., :]

## Hierarchical index example with three key levels

data = reshape(1.:40., 20, 2)
v = collect(zip([:a, :b, :c][rand(1:3,20)], [:x,:y][rand(1:2,20)], [:x,:y][rand(1:2,20)]))
idx = sortperm(v)
A = AxisArray(data[idx,:], SortedVector(v[idx]), [:a, :b])
A[:b, :]
A[[:a,:c], :]
A[(:a,:x), :]
A[(:a,:x,:x), :]
A[ClosedInterval(:a,:b), :]
A[ClosedInterval((:a,:x),(:b,:x)), :]
```

"""
struct SortedVector{T} <: AbstractVector{T}
    data::AbstractVector{T}
end

Base.getindex(v::SortedVector, idx::Int) = v.data[idx]
Base.getindex(v::SortedVector, idx::UnitRange) = SortedVector(v.data[idx])
Base.getindex(v::SortedVector, idx::StepRange) =
    step(idx) > 0 ? SortedVector(v.data[idx]) : error("step must be positive to index a SortedVector")
Base.getindex(v::SortedVector, idx::AbstractVector) =
    issorted(idx) ? SortedVector(v.data[idx]) : error("index must be monotonically increasing to index a SortedVector")

Base.length(v::SortedVector) = length(v.data)
Base.size(v::SortedVector) = size(v.data)
Base.size(v::SortedVector, i) = size(v.data, i)
Base.axes(v::SortedVector) = Base.axes(v.data)

axistrait(::Type{<:SortedVector}) = Dimensional
checkaxis(::SortedVector) = nothing


## Add some special indexing for SortedVector{Tuple}'s to achieve something like
## Panda's hierarchical indexing

axisindexes(ax::Axis{S,SortedVector{T}}, idx) where {T<:Tuple,S} =
    searchsorted(ax.val, idx, 1, length(ax.val), Base.ord(_isless,identity,false,Base.Forward))

axisindexes(ax::Axis{S,SortedVector{T}}, idx::AbstractArray) where {T<:Tuple,S} =
    vcat([axisindexes(ax, i) for i in idx]...)


## Use a modification of `isless`, so that (:a,) is not less than (:a, :b).
## This allows for more natural indexing.

_isless(x,y) = isless(x,y)

function _isless(t1::Tuple, t2::Tuple)
    n1, n2 = length(t1), length(t2)
    for i = 1:min(n1, n2)
        a, b = t1[i], t2[i]
        if !isequal(a, b)
            return _isless(a, b)
        end
    end
    return false
end
# Additionally, we allow comparing scalars against tuples, which enables
# indexing by the first scalar in the tuple
_isless(t1::Tuple, t2) = _isless(t1,(t2,))
_isless(t1, t2::Tuple) = _isless((t1,),t2)

# And then we add special comparisons to Intervals, because by default they
# only define comparisons against Numbers and Dates. We're able to do this on
# our own local function... doing this directly on isless itself would be
# fraught with trouble.
_isless(a::ClosedInterval, b::ClosedInterval) = _isless(a.right, b.left)
_isless(t1::ClosedInterval, t2::Tuple) = _isless(t1, ClosedInterval(t2,t2))
_isless(t1::Tuple, t2::ClosedInterval) = _isless(ClosedInterval(t1,t1), t2)
_isless(a::ClosedInterval, b) = _isless(a, ClosedInterval(b,b))
_isless(a, b::ClosedInterval) = _isless(ClosedInterval(a,a), b)
