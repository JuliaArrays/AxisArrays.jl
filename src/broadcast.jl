# Basic Broadcasting support
# 
# Notes
# -----
# There are a couple ways to go about this
# 1. Redefine broadcast completely and delegate broadcasting to data fields of AxisArrays
# 2. Work with the AbstractArray framework. This would require defining methods for functions like
# 2a. broadcast_indices
# 2b. broadcast_shape
# 2c. containertype
#
# The second approach might be more general, but it would not handle
# broadcasting of arrays like A(i1, i2, i3) and B(i2, i1), where the indices
# might be in another order. 
#
# Reshape does not result in additional allocations, but permutting the dimensions will.
#
# Implementing pairwise is easier, but potentially slower for large numbers of arguments
#
# Issues
# ------
#  broadcasting only works when an axis array is the first argument
#  element type promotion is not done in output_axisarray

# This is a good fallback for simple function application
function Base.broadcast(f::Function, x::AxisArray) 
    AxisArray(broadcast(f, x.data), x.axes)
end


# This alias is useful
typealias Axes{N,Name,T} NTuple{N, Axis{Name, T}}

"""
coerce2axes(A, axes)

Create data array with singleton dimensions and permuted dimensions to match
a set of axes.

This is useful for broadcasting
"""
coerce2axes(A, axes) = A

function coerce2axes(A::AxisArray, axes)

    # TODO add compatibility check

    # permutation
    # put dimensions in same order as axes
    toaxes  = [findin(axes, (ax,))[1] for ax in A.axes]
    perm  = sortperm(toaxes)

    # resize
    new_shape = map(i-> in(i, toaxes) ? length(axes[i]) : 1, 1:length(axes))

    reshape(permutedims(A.data, perm), new_shape)
end



# This is the most general method of the broadcast! function
function Base.broadcast!(f, C::AxisArray, As...)
    # axes = union(As...)
    As_data = [coerce2axes(A, C.axes) for A in As]
    broadcast!(f, C.data, As_data...)
    C
end

# dispatch on first argument
axisarray_union(Bs...) = axisarray_union(filter(B->isa(B, AxisArray), Bs))
axisarray_union(Bs::AxisArray...) = tuple(union([B.axes for B in Bs]...)...)
to_shape(axes::Axes) = map(ax-> length(ax), axes)

function output_axisarray(Bs...)
    axes = axisarray_union(Bs...)

    # TODO need to handle types adequately
    data = zeros(to_shape(axes)...)
    AxisArray(data, axes)
end


Base.broadcast(f, A::AxisArray, Bs...) =
    broadcast!(f, output_axisarray(A, Bs...), A, Bs...)