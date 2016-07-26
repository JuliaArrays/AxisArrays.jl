A = AxisArray(reshape(1:24, 2,3,4), .1:.1:.2, .1:.1:.3, .1:.1:.4)
D = similar(A)
D[1,1,1,1,1] = 10
@test D[1,1,1,1,1] == D[1] == D.data[1] == 10

# Test slices

@test A == A.data
@test A[:,:,:] == A[Axis{:row}(:)] == A[Axis{:col}(:)] == A[Axis{:page}(:)] == A.data[:,:,:]
# Test UnitRange slices
@test A[1:2,:,:] == A.data[1:2,:,:] == A[Axis{:row}(1:2)]  == A[Axis{1}(1:2)] == A[Axis{:row}(Interval(-Inf,Inf))] == A[[true,true],:,:]
@test A[:,1:2,:] == A.data[:,1:2,:] == A[Axis{:col}(1:2)]  == A[Axis{2}(1:2)] == A[Axis{:col}(Interval(0.0, .25))] == A[:,[true,true,false],:]
@test A[:,:,1:2] == A.data[:,:,1:2] == A[Axis{:page}(1:2)] == A[Axis{3}(1:2)] == A[Axis{:page}(Interval(-1., .22))] == A[:,:,[true,true,false,false]]
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

A = AxisArray(reshape(1:32, 2, 2, 2, 2, 2), .1:.1:.2, .1:.1:.2, .1:.1:.2, [:a, :b], [:c, :d])
@test A[Interval(.15, .25), Interval(.05, .15), Interval(.15, .25), :a] == A.data[2:2, 1:1, 2:2, 1, :]
@test A[Axis{:dim_5}(2)] == A.data[:, :, :, :, 2]

# Test vectors
v = AxisArray(collect(.1:.1:10.0), .1:.1:10.0)
@test v[Colon()] === v
@test v[:] == v.data[:] == v[Axis{:row}(:)]
@test v[3:8] == v.data[3:8] == v[Interval(.25,.85)] == v[Axis{:row}(3:8)] == v[Axis{:row}(Interval(.22,.88))]

# Test repeated intervals
A = AxisArray([1:100 -1:-1:-100], .1:.1:10.0, [:c1, :c2])
@test A[2.0..3.0, :] == A[atindex(-0.5..0.5, 25), :] == [20:30 -20:-1:-30]
@test A[2.0..3.0, [:c1,:c2]] == A[atindex(-0.5..0.5, 25), [:c1, :c2]] == [20:30 -20:-1:-30]
@test A[2.0..3.0, :c1] == A[atindex(-0.5..0.5, 25), :c1] == collect(20:30)
@test A[atindex(-0.5..0.5, 25), :c1] == collect(20:30)
@test A[atindex(-0.5..0.5, [25, 35]), :c1] == [20:30 30:40]
@test_throws BoundsError A[atindex(-0.5..0.5, 5), :c1]
@test_throws BoundsError A[atindex(-0.5..0.5, [5, 15, 25]), :]
