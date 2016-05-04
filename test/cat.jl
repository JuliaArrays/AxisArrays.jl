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
