using AxisArrays
using Base.Test

A = AxisArray(reshape(1:24, 2,3,4), .1:.1:.2, .1:.1:.3, .1:.1:.4)
# Test iteration
for (a,b) in zip(A, A.data)
    @test a == b
end
# Cartesian indexing
for idx in eachindex(A)
    @test A[idx] == A.data[idx]
end
# Conversion and similar
@test Array(A) == A.data
@test reshape(A, length(A)) == A.data[:]
@test [A A] == [A.data A.data]
B = similar(A, Float64)
for i in eachindex(A)
    B[i] = A[i]
end
@test A == B
for i=1:length(A)
    @test float(A[i]) === B[i]
end
C = similar(A, 0)
@test isa(C, Array{Int,1})
@test C == []
D = similar(A)
@test size(A) == size(D)
@test eltype(A) == eltype(D)
D[1,1,1,1,1] = 10
@test D[1,1,1,1,1] == D[1] == D.data[1] == 10

# Test slices
@test A == A.data
@test A[:,:,:] == A[Axis{:row}(:)] == A[Axis{:col}(:)] == A[Axis{:page}(:)] == A.data[:,:,:]
# Test UnitRange slices
@test A[1:2,:,:] == A.data[1:2,:,:] == A[Axis{:row}(1:2)]  == A[Axis{1}(1:2)] == A[Axis{:row}(Interval(-Inf,Inf))]
@test A[:,1:2,:] == A.data[:,1:2,:] == A[Axis{:col}(1:2)]  == A[Axis{2}(1:2)] == A[Axis{:col}(Interval(0.0, .25))]
@test A[:,:,1:2] == A.data[:,:,1:2] == A[Axis{:page}(1:2)] == A[Axis{3}(1:2)] == A[Axis{:page}(Interval(-1., .22))]
# Test scalar slices
@test A[2,:,:] == A.data[2,:,:] == A[Axis{:row}(2)]
@test A[:,2,:] == A.data[:,2,:] == A[Axis{:col}(2)]
@test A[:,:,2] == A.data[:,:,2] == A[Axis{:page}(2)]

# Test fallback methods
@test A[[1 2; 3 4]] == A.data[[1 2; 3 4]]
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
@test A[1:2,:].axes[1].val == A.axes[1].val[1:2]
@test A[1:2,:].axes[2].val == 1:Base.trailingsize(A,2)

B = AxisArray(reshape(1:15, 5,3), .1:.1:0.5, [:a, :b, :c])

# Test indexing by Intervals
@test B[Interval(0.0,  0.5), :] == B[Interval(0.0,  0.5)] == B[:,:]
@test B[Interval(0.0,  0.3), :] == B[Interval(0.0,  0.3)] == B[1:3,:]
@test B[Interval(0.15, 0.3), :] == B[Interval(0.15, 0.3)] == B[2:3,:]
@test B[Interval(0.2,  0.5), :] == B[Interval(0.2,  0.5)] == B[2:end,:]
@test B[Interval(0.2,  0.6), :] == B[Interval(0.2,  0.6)] == B[2:end,:]

# Test Categorical indexing
@test B[:, :a] == B[:,1]
@test B[:, :c] == B[:,3]
@test B[:, [:a]] == B[:,[1]]
@test B[:, [:a,:c]] == B[:,[1,3]]

@test B[Axis{:row}(Interval(0.15, 0.3))] == B[2:3,:]

A = AxisArray(reshape(1:256, 4,4,4,4), Axis{:d1}(.1:.1:.4), Axis{:d2}(1//10:1//10:4//10), Axis{:d3}(["1","2","3","4"]), Axis{:d4}([:a, :b, :c, :d]))
@test A.data[1:2,:,:,:] == A[Axis{:d1}(Interval(.1,.2))]       == A[Interval(.1,.2),:,:,:]       == A[Interval(.1,.2),:,:,:,1]       == A[Interval(.1,.2)] 
@test A.data[:,1:2,:,:] == A[Axis{:d2}(Interval(1//10,2//10))] == A[:,Interval(1//10,2//10),:,:] == A[:,Interval(1//10,2//10),:,:,1] == A[:,Interval(1//10,2//10)]
@test A.data[:,:,1:2,:] == A[Axis{:d3}(["1","2"])]             == A[:,:,["1","2"],:]             == A[:,:,["1","2"],:,1]             == A[:,:,["1","2"]]
@test A.data[:,:,:,1:2] == A[Axis{:d4}([:a,:b])]               == A[:,:,:,[:a,:b]]               == A[:,:,:,[:a,:b],1]

# Test vectors
v = AxisArray(collect(.1:.1:10.0), .1:.1:10.0)
@test v[Colon()] === v
@test v[:] == v.data[:] == v[Axis{:row}(:)]
@test v[3:8] == v.data[3:8] == v[Interval(.25,.85)] == v[Axis{:row}(3:8)] == v[Axis{:row}(Interval(.22,.88))]

## Test constructors
# No axis or time args
A = AxisArray(1:3)
@test A.data == 1:3
@test axisnames(A) == (:row,)
@test axisvalues(A) == (1:3,)
A = AxisArray(reshape(1:16, 2,2,2,2))
@test A.data == reshape(1:16, 2,2,2,2)
@test axisnames(A) == (:row,:col,:page,:dim_4)
@test axisvalues(A) == (1:2, 1:2, 1:2, 1:2)
# Just axis names
A = AxisArray(1:3, :a)
@test A.data == 1:3
@test axisnames(A) == (:a,)
@test axisvalues(A) == (1:3,)
A = AxisArray([1 3; 2 4], :a)
@test A.data == [1 3; 2 4]
@test axisnames(A) == (:a, :col)
@test axisvalues(A) == (1:2, 1:2)
# Just axis values
A = AxisArray(1:3, .1:.1:.3)
@test A.data == 1:3
@test axisnames(A) == (:row,)
@test axisvalues(A) == (.1:.1:.3,)
A = AxisArray(reshape(1:16, 2,2,2,2), .5:.5:1)
@test A.data == reshape(1:16, 2,2,2,2)
@test axisnames(A) == (:row,:col,:page,:dim_4)
@test axisvalues(A) == (.5:.5:1, 1:2, 1:2, 1:2)

# Test axisdim
A = AxisArray(reshape(1:24, 2,3,4), Axis{:x}(.1:.1:.2), Axis{:y}(1//10:1//10:3//10), Axis{:z}(["a", "b", "c", "d"]))
@test axisdim(A, Axis{:x}) == axisdim(A, Axis{:x}()) == 1
@test axisdim(A, Axis{:y}) == axisdim(A, Axis{:y}()) == 2
@test axisdim(A, Axis{:z}) == axisdim(A, Axis{:z}()) == 3
# Test axes
@test @inferred(axes(A)) == (Axis{:x}(.1:.1:.2), Axis{:y}(1//10:1//10:3//10), Axis{:z}(["a", "b", "c", "d"]))
@test @inferred(axes(A, Axis{:x})) == @inferred(axes(A, Axis{:x}())) == Axis{:x}(.1:.1:.2)
@test @inferred(axes(A, Axis{:y})) == @inferred(axes(A, Axis{:y}())) == Axis{:y}(1//10:1//10:3//10)
@test @inferred(axes(A, Axis{:z})) == @inferred(axes(A, Axis{:z}())) == Axis{:z}(["a", "b", "c", "d"])
