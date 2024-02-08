Base.BroadcastStyle(::Type{<:AxisArray}) = Broadcast.ArrayStyle{AxisArray}()
Base.BroadcastStyle(::Type{<:Adjoint{T, <:AxisArray{T}}}) where T =
    Broadcast.ArrayStyle{AxisArray}()

# Hijack broadcasting after determining style
function Base.broadcast(f, ::Broadcast.ArrayStyle{AxisArray}, ::Nothing, ::Nothing, As...)
    # We need to make sure we can combine indices of only the AxisArrays before attempting
    # broadcasting. The total broadcasting operation may include other AbstractArrays.
    # We demand that for a given dimension, the axes values and names must match
    # as implemented, this demands exact matching of axes (even floating point nums).
    axesAs = Broadcast.combine_indices(axarrs(As)...)

    # Obtain the underlying data and find the result indices if we were to
    # broadcast all arrays without axis info.
    Bs = data(As)

    # Broadcast using the underlying data
    broadcasted = broadcast(f, Bs...)

    defaxesBs = default_axes(broadcasted)
    axesBs = broadcax(axesAs, defaxesBs)
    return AxisArray(broadcasted, axesBs)
end

broadcax(axes::Tuple, defaxes::Tuple) =
    (broadcax1(axes[1], defaxes[1]), broadcax(tail(axes), tail(defaxes))...)
broadcax(axes::Tuple{}, defaxes::Tuple) = ()
broadcax1(::Tuple{}, x) = ()
function broadcax1(axA::Axis, axB::Axis)
    axAname, axAvalues = axisname(axA), axisvalues(axA)[1]
    axAname != axisname(axB) && return axA
    if typeof(axAvalues) <: Base.OneTo
        # We believe this was a default axis, not just an axis that happened to
        # have the default name
        return typeof(axA)(Base.OneTo(length(axB)))
    else
        error("axis values did not match.")
    end
end

# Compares the value indices and axis names (note: AxisArrays.axes, not Base.axes)
Broadcast.broadcast_indices(::Broadcast.ArrayStyle{AxisArray}, A) = axes(A)
Broadcast.broadcast_indices(::Broadcast.ArrayStyle{AxisArray}, A::Adjoint{T,S}) where
    {T, S<:AxisArray{T,1}} = (Axis{:row}(Base.OneTo(1)), axes(A.parent)[1])
Broadcast.broadcast_indices(::Broadcast.ArrayStyle{AxisArray}, A::Adjoint{T,S}) where
    {T, S<:AxisArray{T,2}} = tupswap(axes(A.parent))

# Helper functions
# Given a tuple `A`, return a tuple containing only the AxisArrays (or their adjoints) in `A`
axarrs(A::Tuple{AxisArray, Vararg}) = (A[1], axarrs(Base.tail(A))...)
axarrs(A::Tuple{Adjoint{T, <:AxisArray} where T, Vararg}) = (A[1], axarrs(Base.tail(A))...)
axarrs(A::Tuple{Any, Vararg}) = axarrs(Base.tail(A))
axarrs(A::Tuple{}) = ()

data(A::Tuple{AxisArray,Vararg}) = (A[1].data, data(Base.tail(A))...)
data(A::Tuple{Adjoint{T, <:AxisArray} where T, Vararg}) =
    (adjoint(A[1].parent.data), data(Base.tail(A))...)
data(A::Tuple{Any,Vararg}) = (A[1], data(Base.tail(A))...)
data(A::Tuple{}) = ()

tupswap(A::Tuple{Any,Any}) = (A[2],A[1])
