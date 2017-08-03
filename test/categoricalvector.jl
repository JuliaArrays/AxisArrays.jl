# Test CategoricalVector with a hierarchical index (indexed using Tuples)
srand(1234)
data = reshape(1.:40., 20, 2)
v = collect(zip([:a, :b, :c][rand(1:3,20)], [:x,:y][rand(1:2,20)], [:x,:y][rand(1:2,20)]))
idx = sortperm(v)
A = AxisArray(data[idx,:], AxisArrays.CategoricalVector(v[idx]), [:a, :b])
@test A[:b, :] == A[5:12, :]
@test A[[:a,:c], :] == A[[1:4;13:end], :]
@test A[(:a,:y), :] == A[2:4, :]
@test A[(:c,:y,:y), :] == A[16:end, :]
@test AxisArrays.axistrait(axes(A)[1]) <: AxisArrays.Categorical

v = AxisArrays.CategoricalVector(collect([1; 8; 10:15]))
@test AxisArrays.axistrait(axes(A)[1]) <: AxisArrays.Categorical
A = AxisArray(reshape(1:16, 8, 2), v, [:a, :b])
@test A[Axis{:row}(AxisArrays.CategoricalVector([15]))] == AxisArray(reshape(A.data[8, :], 1, 2), AxisArrays.CategoricalVector([15]), [:a, :b])
@test A[Axis{:row}(AxisArrays.CategoricalVector([15])), 1] == AxisArray([A.data[8, 1]], AxisArrays.CategoricalVector([15]))
@test AxisArrays.axistrait(axes(A)[1]) <: AxisArrays.Categorical

# TODO: maybe make this work? Would require removing or modifying Base.getindex(A::AxisArray, idxs::Idx...)
# @test A[AxisArrays.CategoricalVector([15]), 1] == AxisArray([A.data[8, 1]], AxisArrays.CategoricalVector([15]))
