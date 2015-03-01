# these methods are not specific to time series necessarily, but quarantined here for the time being

import TimeSeries.moving, Base.merge

# only works for single column AxisArrays
function moving(a::AxisArray, f::Function, n::Int)
    m = length(a)-n+1
    res = zeros(m)
    for i in 1:m
        res[i] = f(a[Interval(a.axes[1][i],a.axes[1][i+n-1])])
    end
    AxisArray(res, (a.axes[1][n:end],))
end

# this is @tshort implementation with correction to overlaps

function overlaps(ordered1, ordered2)
    i = j = 1
    idx1 = Int[]
    idx2 = Int[]
    while i < length(ordered1) + 1 && j < length(ordered2) + 1
        if ordered1[i] > ordered2[j]
            j += 1
        elseif ordered1[i] < ordered2[j]
            i += 1
        else
            push!(idx1, i)
            push!(idx2, j)
            i += 1
            j += 1
        end
    end
    (idx1, idx2)        
end

function merge(a1::AxisArray, a2::AxisArray)
    idx1, idx2 = overlaps(a1.axes[1], a2.axes[1])
    vals1      = a1[Axis{:row}(idx1)].data
    vals2      = a2[Axis{:row}(idx2)].data
    vals       = reshape(hcat(vals1,vals2), size(vals1)..., 2)
    AxisArray(vals,(a1.axes[1][idx1], a1.axes[2], ["stock1","stock2"]))
end
