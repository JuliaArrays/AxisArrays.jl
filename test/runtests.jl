using AxisArrays
using Base.Test

A = AxisArray(reshape(1:24, 2,3,4), (.1:.1:.2, .1:.1:.3, .1:.1:.4))
# Test enumeration
for (a,b) in zip(A, A.data)
    @test a == b
end
for idx in eachindex(A)
    @test A[idx] == A.data[idx]
end

# Test slices
@test A == A.data
@test A[:,:,:] == A[Axis{:row}(:)] == A[Axis{:col}(:)] == A[Axis{:page}(:)] == A.data[:,:,:]
# Test UnitRange slices
@test A[1:2,:,:] == A.data[1:2,:,:] == A[Axis{:row}(1:2)]
@test A[:,1:2,:] == A.data[:,1:2,:] == A[Axis{:col}(1:2)]
@test A[:,:,1:2] == A.data[:,:,1:2] == A[Axis{:page}(1:2)]
# Test scalar slices
@test A[2,:,:] == A.data[2,:,:] == A[Axis{:row}(2)]
@test A[:,2,:] == A.data[:,2,:] == A[Axis{:col}(2)]
@test A[:,:,2] == A.data[:,:,2] == A[Axis{:page}(2)]

# Test axis restrictions
@test A[:,:,:].axes == A.axes

@test A[Axis{:row}(1:2)].axes[1] == A.axes[1][1:2]
@test A[Axis{:row}(1:2)].axes[2:3] == A.axes[2:3]

@test A[Axis{:col}(1:2)].axes[2] == A.axes[2][1:2]
@test A[Axis{:col}(1:2)].axes[[1,3]] == A.axes[[1,3]]

@test A[Axis{:page}(1:2)].axes[3] == A.axes[3][1:2]
@test A[Axis{:page}(1:2)].axes[1:2] == A.axes[1:2]

# Linear indexing across multiple dimensions drops tracking of those dims
@test A[:].axes == ()
@test A[1:2,:].axes == (A.axes[1][1:2],)
