# Additions to Base's searchsorted functionality
"""
    searchsortednearest(vec::AbstractVector, x)

Like `searchsortedfirst` or `searchsortedlast`, this returns the the index of
the element in the sorted vector `vec` whose value is closest to `x`, rounding
up. If there are multiple elements that are equally close to `x`, this will
return the first index if `x` is less than or equal to those in the vector or
the last index if `x` is greater.
"""
function searchsortednearest(vec::AbstractVector, x)
    idx = searchsortedfirst(vec, x) # Returns the first idx | vec[idx] >= x
    if idx > 1 && (idx > length(vec) || (vec[idx] - x) > (x - vec[idx-1]))
        idx -= 1 # The previous element is closer
    end
    return idx
end
# Base only specializes searching ranges by Numbers; so optimize for Intervals
function Base.searchsorted(a::AbstractRange, I::ClosedInterval)
    searchsortedfirst(a, I.left):searchsortedlast(a, I.right)
end

"""
The internal `Extrapolated` module contains implementations for indexing and
searching into ranges beyond their bounds. The `@inbounds` macro is not
sufficient since it can be turned off by `--check-bounds=yes`.
"""
module Extrapolated
using IntervalSets: ClosedInterval

function searchsortednearest(vec::AbstractRange, x)
    idx = searchsortedfirst(vec, x) # Returns the first idx | vec[idx] >= x
    if (getindex(vec, idx) - x) > (x - getindex(vec, idx-1))
        idx -= 1 # The previous element is closer
    end
    return idx
end

"""
    searchsorted(a::AbstractRange, I::ClosedInterval)

Return the indices of the range that fall within an interval without checking
bounds, possibly extrapolating outside the range if needed.
"""
function searchsorted(a::AbstractRange, I::ClosedInterval)
    searchsortedfirst(a, I.left):searchsortedlast(a, I.right)
end

# When running with `--check-bounds=yes` (like on Travis), the bounds-check isn't elided
@inline function getindex(v::AbstractRange{T}, i::Integer) where T
    convert(T, first(v) + (i-1)*step(v))
end
@inline function getindex(r::AbstractRange, s::AbstractRange{<:Integer})
    f = first(r)
    st = oftype(f, f + (first(s)-1)*step(r))
    range(st, step=step(r)*step(s), length=length(s))
end
getindex(r::AbstractRange, I::Array) = [getindex(r, i) for i in I]
@inline getindex(r::StepRangeLen, i::Integer) = Base.unsafe_getindex(r, i)
@inline function getindex(r::StepRangeLen, s::AbstractUnitRange)
    soffset = 1 + (r.offset - first(s))
    soffset = clamp(soffset, 1, length(s))
    ioffset = first(s) + (soffset-1)
    if ioffset == r.offset
        StepRangeLen(r.ref, r.step, length(s), max(1,soffset))
    else
        StepRangeLen(r.ref + (ioffset-r.offset)*r.step, r.step, length(s), max(1,soffset))
    end
end

function searchsortedlast(a::AbstractRange, x)
    step(a) == 0 && throw(ArgumentError("ranges with a zero step are unsupported"))
    n = round(Integer,(x-first(a))/step(a))+1
    isless(x, getindex(a, n)) ? n-1 : n
end
function searchsortedfirst(a::AbstractRange, x)
    step(a) == 0 && throw(ArgumentError("ranges with a zero step are unsupported"))
    n = round(Integer,(x-first(a))/step(a))+1
    isless(getindex(a, n), x) ? n+1 : n
end
function searchsortedlast(a::AbstractRange{<:Integer}, x)
    step(a) == 0 && throw(ArgumentError("ranges with a zero step are unsupported"))
    fld(floor(Integer,x)-first(a),step(a))+1
end
function searchsortedfirst(a::AbstractRange{<:Integer}, x)
    step(a) == 0 && throw(ArgumentError("ranges with a zero step are unsupported"))
    -fld(floor(Integer,-x)+first(a),step(a))+1
end
function searchsortedfirst(a::AbstractRange{<:Integer}, x::Unsigned)
    step(a) == 0 && throw(ArgumentError("ranges with a zero step are unsupported"))
    -fld(first(a)-signed(x),step(a))+1
end
function searchsortedlast(a::AbstractRange{<:Integer}, x::Unsigned)
    step(a) == 0 && throw(ArgumentError("ranges with a zero step are unsupported"))
    fld(signed(x)-first(a),step(a))+1
end
end
