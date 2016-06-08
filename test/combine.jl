A1data, A2data = [1 3; 2 4], [5 7; 6 8]

A1 = AxisArray(A1data, Axis{:Row}([:First, :Second]), Axis{:Col}([:A, :B]))
A2 = AxisArray(A2data, Axis{:Row}([:Third, :Fourth]), Axis{:Col}([:A, :B]))
@test isa(cat(1, A1, A2), AxisArray)
@test cat(1, A1, A2) == AxisArray(vcat(A1data, A2data),
                                  Axis{:Row}([:First, :Second, :Third, :Fourth]), Axis{:Col}([:A, :B]))

A2 = AxisArray(A2data, Axis{:Row}([:First, :Second]), Axis{:Col}([:C, :D]))
@test isa(cat(2, A1, A2), AxisArray)
@test cat(2, A1, A2) == AxisArray(hcat(A1data, A2data),
                                  Axis{:Row}([:First, :Second]), Axis{:Col}([:A, :B, :C, :D]))

A2 = AxisArray(A2data, Axis{:Row}([:First, :Second]), Axis{:Col}([:A, :B]))
@test isa(cat(3, A1, A2), AxisArray)
@test cat(3, A1, A2) == AxisArray(cat(3, A1data, A2data),
                                       Axis{:Row}([:First, :Second]), Axis{:Col}([:A, :B]),
                                       Axis{:page}(1:2))

Adata, Bdata, ABdata = randn(4,4,2), randn(4,4,2), zeros(6,6,2)
A = AxisArray(Adata, Axis{:A}([1,2,3,4]), Axis{:B}([10.,20,30,40]), Axis{:C}([:First, :Second]))
B = AxisArray(Bdata, Axis{:A}([3,4,5,6]), Axis{:B}([30.,40,50,60]), Axis{:C}([:First, :Second]))
ABdata[1:4,1:4,:] = Adata
ABdata[3:6,3:6,:] = Bdata
@test merge(A,B) == AxisArray(ABdata, Axis{:A}([1,2,3,4,5,6]), Axis{:B}([10.,20,30,40,50,60]), Axis{:C}([:First, :Second]))
