A = AxisArray(reshape(1:24, 2,3,4), .1:.1:.2, .1:.1:.3, .1:.1:.4)
D = similar(A)
D[1,1,1,1,1] = 10
@test @inferred(D[1,1,1,1,1]) == @inferred(D[1]) == D.data[1] == 10
@test @inferred(D[1,1,1,:]) == @inferred(D[1,1,1,1:1]) == @inferred(D[1,1,1,[1]]) == AxisArray([10], Axis{:dim_4}(Base.OneTo(1)))

# Test slices

@test A == A.data
@test A[:,:,:] == A[Axis{:row}(:)] == A[Axis{:col}(:)] == A[Axis{:page}(:)] == A.data[:,:,:]
# Test UnitRange slices
@test @inferred(A[1:2,:,:]) == A.data[1:2,:,:] == @inferred(A[Axis{:row}(1:2)])  == @inferred(A[Axis{1}(1:2)]) == @inferred(A[Axis{:row}(ClosedInterval(-Inf,Inf))]) == @inferred(A[[true,true],:,:])
@test @inferred(view(A,1:2,:,:)) == A.data[1:2,:,:] == @inferred(view(A,Axis{:row}(1:2))) == @inferred(view(A,Axis{1}(1:2))) == @inferred(view(A,Axis{:row}(ClosedInterval(-Inf,Inf)))) == @inferred(view(A,[true,true],:,:))
@test @inferred(A[:,1:2,:]) == A.data[:,1:2,:] == @inferred(A[Axis{:col}(1:2)])  == @inferred(A[Axis{2}(1:2)]) == @inferred(A[Axis{:col}(ClosedInterval(0.0, .25))]) == @inferred(A[:,[true,true,false],:])
@test @view(A[:,1:2,:]) == A.data[:,1:2,:] == @view(A[Axis{:col}(1:2)])  == @view(A[Axis{2}(1:2)]) == @view(A[Axis{:col}(ClosedInterval(0.0, .25))]) == @view(A[:,[true,true,false],:])
@test A[:,:,1:2] == A.data[:,:,1:2] == A[Axis{:page}(1:2)] == A[Axis{3}(1:2)] == A[Axis{:page}(ClosedInterval(-1., .22))] == A[:,:,[true,true,false,false]]
@test @view(A[:,:,1:2]) == @view(A.data[:,:,1:2]) == @view(A[Axis{:page}(1:2)]) == @view(A[Axis{3}(1:2)]) == @view(A[Axis{:page}(ClosedInterval(-1., .22))]) == @view(A[:,:,[true,true,false,false]])
# Test scalar slices
@test A[2,:,:] == A.data[2,:,:] == A[Axis{:row}(2)]
@test A[:,2,:] == A.data[:,2,:] == A[Axis{:col}(2)]
@test A[:,:,2] == A.data[:,:,2] == A[Axis{:page}(2)]

# Test fallback methods
@test A[[1 2; 3 4]] == @view(A[[1 2; 3 4]]) == A.data[[1 2; 3 4]]
@test A[] == A.data[]

# Test axis restrictions
@test A[:,:,:].axes == A.axes

@test A[Axis{:row}(1:2)].axes[1].val == A.axes[1].val[1:2]
@test A[Axis{:row}(1:2)].axes[2:3] == A.axes[2:3]

@test A[Axis{:col}(1:2)].axes[2].val == A.axes[2].val[1:2]
@test A[Axis{:col}(1:2)].axes[[1,3]] == A.axes[[1,3]]

@test A[Axis{:page}(1:2)].axes[3].val == A.axes[3].val[1:2]
@test A[Axis{:page}(1:2)].axes[1:2] == A.axes[1:2]

# Linear indexing across multiple dimensions drops tracking of those dims
@test A[:].axes[1].val == 1:length(A)
# TODO: remove the next 4 lines when we no longer feel we need to test for this
VERSION >= v"0.6.0-dev" && info("partial linear indexing deprecation warning is expected")
B = A[1:2,:]
@test B.axes[1].val == A.axes[1].val[1:2]
@test B.axes[2].val == 1:Base.trailingsize(A,2)
B2 = reshape(A, Val{2})
B = B2[1:2,:]
@test B.axes[1].val == A.axes[1].val[1:2]
@test B.axes[2].val == 1:Base.trailingsize(A,2)

B = AxisArray(reshape(1:15, 5,3), .1:.1:0.5, [:a, :b, :c])

# Test indexing by Intervals
@test B[ClosedInterval(0.0,  0.5), :] == B[ClosedInterval(0.0,  0.5)] == B[:,:]
@test B[ClosedInterval(0.0,  0.3), :] == B[ClosedInterval(0.0,  0.3)] == B[1:3,:]
@test B[ClosedInterval(0.15, 0.3), :] == B[ClosedInterval(0.15, 0.3)] == B[2:3,:]
@test B[ClosedInterval(0.2,  0.5), :] == B[ClosedInterval(0.2,  0.5)] == B[2:end,:]
@test B[ClosedInterval(0.2,  0.6), :] == B[ClosedInterval(0.2,  0.6)] == B[2:end,:]
@test @view(B[ClosedInterval(0.0,  0.5), :]) == @view(B[ClosedInterval(0.0,  0.5)]) == B[:,:]
@test @view(B[ClosedInterval(0.0,  0.3), :]) == @view(B[ClosedInterval(0.0,  0.3)]) == B[1:3,:]
@test @view(B[ClosedInterval(0.15, 0.3), :]) == @view(B[ClosedInterval(0.15, 0.3)]) == B[2:3,:]
@test @view(B[ClosedInterval(0.2,  0.5), :]) == @view(B[ClosedInterval(0.2,  0.5)]) == B[2:end,:]
@test @view(B[ClosedInterval(0.2,  0.6), :]) == @view(B[ClosedInterval(0.2,  0.6)]) == B[2:end,:]

# Test Categorical indexing
@test B[:, :a] == @view(B[:, :a]) == B[:,1]
@test B[:, :c] == @view(B[:, :c]) == B[:,3]
@test B[:, [:a]] == @view(B[:, [:a]]) == B[:,[1]]
@test B[:, [:a,:c]] == @view(B[:, [:a,:c]]) == B[:,[1,3]]

@test B[Axis{:row}(ClosedInterval(0.15, 0.3))] == @view(B[Axis{:row}(ClosedInterval(0.15, 0.3))]) == B[2:3,:]

A = AxisArray(reshape(1:256, 4,4,4,4), Axis{:d1}(.1:.1:.4), Axis{:d2}(1//10:1//10:4//10), Axis{:d3}(["1","2","3","4"]), Axis{:d4}([:a, :b, :c, :d]))
ax1 = axes(A)[1]
@test A[Axis{:d1}(2)] == A[ax1(2)]
@test A.data[1:2,:,:,:] == A[Axis{:d1}(ClosedInterval(.1,.2))]       == A[ClosedInterval(.1,.2),:,:,:]       == A[ClosedInterval(.1,.2),:,:,:,1]       == A[ClosedInterval(.1,.2)]
@test A.data[:,1:2,:,:] == A[Axis{:d2}(ClosedInterval(1//10,2//10))] == A[:,ClosedInterval(1//10,2//10),:,:] == A[:,ClosedInterval(1//10,2//10),:,:,1] == A[:,ClosedInterval(1//10,2//10)]
@test A.data[:,:,1:2,:] == A[Axis{:d3}(["1","2"])]             == A[:,:,["1","2"],:]             == A[:,:,["1","2"],:,1]             == A[:,:,["1","2"]]
@test A.data[:,:,:,1:2] == A[Axis{:d4}([:a,:b])]               == A[:,:,:,[:a,:b]]               == A[:,:,:,[:a,:b],1]

A = AxisArray(reshape(1:32, 2, 2, 2, 2, 2), .1:.1:.2, .1:.1:.2, .1:.1:.2, [:a, :b], [:c, :d])
@test A[ClosedInterval(.15, .25), ClosedInterval(.05, .15), ClosedInterval(.15, .25), :a] == A.data[2:2, 1:1, 2:2, 1, :]
@test A[Axis{:dim_5}(2)] == A.data[:, :, :, :, 2]

# Test vectors
v = AxisArray(collect(.1:.1:10.0), .1:.1:10.0)
@test v[Colon()] == v
@test v[:] == v.data[:] == v[Axis{:row}(:)]
@test v[3:8] == v.data[3:8] == v[ClosedInterval(.25,.85)] == v[Axis{:row}(3:8)] == v[Axis{:row}(ClosedInterval(.22,.88))]

# Test repeated intervals, for different range types

# First, since integers mean "location" rather than value, we have to
# create a number type from which we build a StepRange but which is
# not an Int.
module IL  # put in a module so this file can be re-run
immutable IntLike <: Number
    val::Int
end
Base.one(x::IntLike) = IntLike(0)
Base.zero(x::IntLike) = IntLike(0)
Base.isless(x::IntLike, y::IntLike) = isless(x.val, y.val)
Base.:+(x::IntLike, y::IntLike) = IntLike(x.val+y.val)
Base.:-(x::IntLike, y::IntLike) = IntLike(x.val-y.val)
Base.:/(x::IntLike, y::IntLike) = x.val / y.val
Base.rem(x::IntLike, y::IntLike) = IntLike(rem(x.val, y.val))
Base.div(x::IntLike, y::IntLike) = div(x.val, y.val)
Base.:*(x::IntLike, y::Int) = IntLike(x.val * y)
Base.:*(x::Int, y::IntLike) = y*x
Base.:/(x::IntLike, y::Int) = IntLike(x.val / y)
Base.promote_rule(::Type{IntLike}, ::Type{Int}) = Int
Base.convert(::Type{Int}, x::IntLike) = x.val
using AxisArrays
AxisArrays.axistrait(::AbstractVector{IntLike}) = AxisArrays.Dimensional
end

for (r, Irel) in ((0.1:0.1:10.0, -0.5..0.5),  # FloatRange
                  (linspace(0.1, 10.0, 100), -0.51..0.51),  # LinSpace
                  (IL.IntLike(1):IL.IntLike(1):IL.IntLike(100),
                   IL.IntLike(-5)..IL.IntLike(5))) # StepRange
    Iabs = r[20]..r[30]
    A = AxisArray([1:100 -1:-1:-100], r, [:c1, :c2])
    @test A[Iabs, :] == A[atindex(Irel, 25), :] == [20:30 -20:-1:-30]
    @test A[Iabs, :] == A[r[25]+Irel, :] == [20:30 -20:-1:-30]
    @test A[Iabs, [:c1,:c2]] == A[atindex(Irel, 25), [:c1, :c2]] == [20:30 -20:-1:-30]
    @test A[Iabs, :c1] == A[atindex(Irel, 25), :c1] == collect(20:30)
    @test A[atindex(Irel, 25), :c1] == collect(20:30)
    @test A[atindex(Irel, [25, 35]), :c1] == [20:30 30:40]
    @test A[r[[25, 35]] + Irel,  :c1] == [20:30 30:40]
    @test_throws BoundsError A[atindex(Irel, 5), :c1]
    @test_throws BoundsError A[atindex(Irel, [5, 15, 25]), :]

    B = A[r[[25, 35]] + Irel,  :c1]
    @test B[:,:] == B[Irel, :] == [20:30 30:40]
end

# Indexing with CartesianIndex
A = AxisArray(reshape(1:15, 3, 5), :x, :y)
@test A[2,2,CartesianIndex(())] == 5
@test A[2,CartesianIndex(()),2] == 5
@test A[CartesianIndex(()),2,2] == 5
A3 = AxisArray(reshape(1:24, 4, 3, 2), :x, :y, :z)
@test A3[2,CartesianIndex(2,2)] == 18
@test A3[CartesianIndex(2,2),2] == 18
@test A3[CartesianIndex(2,2,2)] == 18

# Extracting the full axis
axx = @inferred(A[Axis{:x}])
@test isa(axx, Axis{:x})
@test axx.val == 1:3
axy = @inferred(A[Axis{:y}])
@test isa(axy, Axis{:y})
@test axy.val == 1:5
@test_throws ArgumentError A[Axis{:z}]

# Test for the expected exception type given repeated axes
A = AxisArray(rand(2,2), :x, :y)
@test_throws ArgumentError A[Axis{:x}(1), Axis{:x}(1)]
@test_throws ArgumentError A[Axis{:y}(1), Axis{:y}(1)]

# Reductions (issues #66, #62)
@test maximum(A3, 1) == reshape([4 16; 8 20; 12 24], 1, 3, 2)
@test maximum(A3, 2) == reshape([9 21; 10 22; 11 23; 12 24], 4, 1, 2)
@test maximum(A3, 3) == reshape(A3[:,:,2], 4, 3, 1)
acc = zeros(Int, 4, 1, 2)
Base.mapreducedim!(x->x>5, +, acc, A3)
@test acc == reshape([1 3; 2 3; 2 3; 2 3], 4, 1, 2)

# Indexing by value using `atvalue`
A = AxisArray([1 2; 3 4], Axis{:x}([1.0,4.0]), Axis{:y}([2.0,6.1]))
@test @inferred(A[atvalue(1.0)]) == @inferred(A[atvalue(1.0), :]) == [1,2]
# `atvalue` doesn't require same type:
@test @inferred(A[atvalue(1)]) == @inferred(A[atvalue(1), :]) ==[1,2]
@test A[atvalue(4.0)] == A[atvalue(4.0),:] == [3,4]
@test A[atvalue(4)] == A[atvalue(4),:] == [3,4]
@test_throws BoundsError A[atvalue(5.0)]
@test @inferred(A[atvalue(1.0), atvalue(2.0)]) == 1
@test @inferred(A[:, atvalue(2.0)]) == [1,3]
@test @inferred(A[Axis{:x}(atvalue(4.0))]) == [3,4]
@test @inferred(A[Axis{:y}(atvalue(6.1))]) == [2,4]
@test @inferred(A[Axis{:x}(atvalue(4.00000001))]) == [3,4]
@test @inferred(A[Axis{:x}(atvalue(2.0, atol=5))]) == [1,2]
@test_throws BoundsError A[Axis{:x}(atvalue(4.00000001, rtol=0))]

# Indexing by value into an OffsetArray
A = AxisArray(OffsetArrays.OffsetArray([1 2; 3 4], 0:1, 1:2),
    Axis{:x}([1.0,4.0]), Axis{:y}([2.0,6.1]))
@test_broken @inferred(A[atvalue(4.0)]) == [3,4]
@test @inferred(A[:, atvalue(2.0)]) == OffsetArrays.OffsetArray([1,3], 0:1)
@test_throws BoundsError A[atvalue(5.0)]

# Indexing by value directly is forbidden for indexes that are Real
@test_throws ArgumentError A[4.0]
@test_throws ArgumentError A[BigFloat(1.0)]
@test_throws ArgumentError A[1.0f0]
@test_throws ArgumentError A[:,6.1]
