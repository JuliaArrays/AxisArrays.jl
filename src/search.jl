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
    unsafe_searchsorted(a::Range, I::Interval)

Return the indices of the range that fall within an interval without checking
bounds, possibly extrapolating outside the range if needed.
"""
function unsafe_searchsorted(a::Range, I::Interval)
    unsafe_searchsortedfirst(a, I.lo):unsafe_searchsortedlast(a, I.hi)
end

function unsafe_searchsortedlast{T<:Number}(a::Range{T}, x::Number)
    if step(a) == 0
        isless(x, first(a)) ? 0 : length(a)
    else
        n = round(Integer,(x-first(a))/step(a))+1
        isless(x, unsafe_getindex(a, n)) ? n-1 : n
    end
end
function unsafe_searchsortedfirst{T<:Number}(a::Range{T}, x::Number)
    if step(a) == 0
        isless(first(a), x) ? length(a)+1 : 1
    else
        n = round(Integer,(x-first(a))/step(a))+1
        isless(unsafe_getindex(a, n), x) ? n+1 : n
    end
end
function unsafe_searchsortedlast{T<:Integer}(a::Range{T}, x::Number)
    if step(a) == 0
        isless(x, first(a)) ? 0 : length(a)
    else
        fld(floor(Integer,x)-first(a),step(a))+1
    end
end
function unsafe_searchsortedfirst{T<:Integer}(a::Range{T}, x::Number)
    if step(a) == 0
        isless(first(a), x) ? length(a)+1 : 1
    else
        -fld(floor(Integer,-x)+first(a),step(a))+1
    end
end
function unsafe_searchsortedfirst{T<:Integer}(a::Range{T}, x::Unsigned)
    if step(a) == 0
        isless(first(a), x) ? length(a)+1 : 1
    else
        -fld(first(a)-signed(x),step(a))+1
    end
end
function unsafe_searchsortedlast{T<:Integer}(a::Range{T}, x::Unsigned)
    if step(a) == 0
        isless(x, first(a)) ? 0 : length(a)
    else
        fld(signed(x)-first(a),step(a))+1
    end
end
