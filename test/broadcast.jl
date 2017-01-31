## tests

x_ax = Axis{:x}(collect(1:10))
y_ax = Axis{:y}(collect(1:15))
z_ax = Axis{:z}(collect(1:13))

A = AxisArray(rand(10, 15, 13), (x_ax, y_ax, z_ax))
B = AxisArray(rand(10), (x_ax, ))
C = AxisArray(rand(15), (y_ax, ))
D = AxisArray(rand(13, 10), (z_ax, x_ax))

@test size(AxisArrays.coerce2axes(D, A.axes)) == (10, 1, 13)

@test isa(exp.(A), AxisArray)
@test isa(broadcast(+, B, C), AxisArray)
@test isa(broadcast(+, A, C), AxisArray)
@test isa(broadcast(+, C, A), AxisArray)
@test isa(D .+ C, AxisArray)
@test_approx_eq (B.+C).data  (B.data .+ C.data') 
