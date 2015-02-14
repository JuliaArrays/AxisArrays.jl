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
# TODO: how should the axes behave here?
@test A[:] == A.data[:]
@test A[:,1] == A.data[:,1]
@test A[1,:] == A.data[1,:]
@test A[:,1,1] == A.data[:,1,1]
@test A[1,:,1] == A.data[1,:,1]
@test A[1,1,:] == A.data[1,1,:]
