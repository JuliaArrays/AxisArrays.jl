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

# We depend upon extrapolative behaviors in searching ranges to shift axes.
# This can be done by stealing Base's implementations and removing the bounds-
# correcting min/max.

# TODO: This could plug into the sorting system better, but it's fine for now
# TODO: This needs to support Dates.
"""
    unsafe_searchsorted(a::Range, I::ClosedInterval)

Return the indices of the range that fall within an interval without checking
bounds, possibly extrapolating outside the range if needed.
"""
function unsafe_searchsorted(a::Range, I::ClosedInterval)
    unsafe_searchsortedfirst(a, I.left):unsafe_searchsortedlast(a, I.right)
end
# Base only specializes searching ranges by Numbers; so optimize for Intervals
function Base.searchsorted(a::Range, I::ClosedInterval)
    searchsortedfirst(a, I.left):searchsortedlast(a, I.right)
end

# When running with "--check-bounds=yes" (like on Travis), the bounds-check isn't elided
@inline function inbounds_getindex{T}(v::Range{T}, i::Integer)
    convert(T, first(v) + (i-1)*step(v))
end
@inline function inbounds_getindex{T<:Integer}(r::Range, s::Range{T})
    f = first(r)
    st = oftype(f, f + (first(s)-1)*step(r))
    range(st, step(r)*step(s), length(s))
end
if VERSION < v"0.6.0-dev.2390"
    include_string("""
    @inline function inbounds_getindex{T}(r::FloatRange{T}, i::Integer)
        convert(T, (r.start + (i-1)*r.step)/r.divisor)
    end
    @inline function inbounds_getindex(r::FloatRange, s::OrdinalRange)
        FloatRange(r.start + (first(s)-1)*r.step, step(s)*r.step, length(s), r.divisor)
    end
    """)
else
    include_string("""
    @inline inbounds_getindex(r::StepRangeLen, i::Integer) = Base.unsafe_getindex(r, i)
    @inline function inbounds_getindex(r::StepRangeLen, s::OrdinalRange)
        vfirst = Base.unsafe_getindex(r, first(s))
        StepRangeLen(vfirst, step(r)*step(s), length(s))
    end
    """)
end

function unsafe_searchsortedlast{T<:Number}(a::Range{T}, x::Number)
    step(a) == 0 && throw(ArgumentError("ranges with a zero step are unsupported"))
    n = round(Integer,(x-first(a))/step(a))+1
    isless(x, inbounds_getindex(a, n)) ? n-1 : n
end
function unsafe_searchsortedfirst{T<:Number}(a::Range{T}, x::Number)
    step(a) == 0 && throw(ArgumentError("ranges with a zero step are unsupported"))
    n = round(Integer,(x-first(a))/step(a))+1
    isless(inbounds_getindex(a, n), x) ? n+1 : n
end
function unsafe_searchsortedlast{T<:Integer}(a::Range{T}, x::Number)
    step(a) == 0 && throw(ArgumentError("ranges with a zero step are unsupported"))
    fld(floor(Integer,x)-first(a),step(a))+1
end
function unsafe_searchsortedfirst{T<:Integer}(a::Range{T}, x::Number)
    step(a) == 0 && throw(ArgumentError("ranges with a zero step are unsupported"))
    -fld(floor(Integer,-x)+first(a),step(a))+1
end
function unsafe_searchsortedfirst{T<:Integer}(a::Range{T}, x::Unsigned)
    step(a) == 0 && throw(ArgumentError("ranges with a zero step are unsupported"))
    -fld(first(a)-signed(x),step(a))+1
end
function unsafe_searchsortedlast{T<:Integer}(a::Range{T}, x::Unsigned)
    step(a) == 0 && throw(ArgumentError("ranges with a zero step are unsupported"))
    fld(signed(x)-first(a),step(a))+1
end
