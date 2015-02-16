using AxisArrays
using Base.Test

A = AxisArray(reshape(1:24, 2,3,4))
# Test enumeration
for (a,b) in zip(A, A.data)
    @test a == b
end
for idx in eachindex(A)
    @test A[idx] == A.data[idx]
end

# Test slices
@test A == A.data
@test A[:,:,:] == A.data[:,:,:] == A[Axis{:row}(:)] == A[Axis{:col}(:)] == A[Axis{:page}(:)]
# Test UnitRange slices
@test A[1:2,:,:] == A.data[1:2,:,:] == A[Axis{:row}(1:2)]
@test A[:,1:2,:] == A.data[:,1:2,:] == A[Axis{:col}(1:2)]
@test A[:,:,1:2] == A.data[:,:,1:2] == A[Axis{:page}(1:2)]
# Test scalar slices
@test A[2,:,:] == A.data[2,:,:] == A[Axis{:row}(2)]
@test A[:,2,:] == A.data[:,2,:] == A[Axis{:col}(2)]
@test A[:,:,2] == A.data[:,:,2] == A[Axis{:page}(2)]