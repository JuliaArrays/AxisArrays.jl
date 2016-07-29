A = AxisArray(reshape(1:24, 2,3,4), .1:.1:.2, .1:.1:.3, .1:.1:.4)
@test_throws ArgumentError AxisArray(reshape(1:24, 2,3,4), .1:.1:.1, .1:.1:.3, .1:.1:.4)
@test_throws ArgumentError AxisArray(reshape(1:24, 2,3,4), .1:.1:.1, .1:.1:.3)
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
# Test modifying a particular axis
E = similar(A, Float64, Axis{:col}(1:2))
@test size(E) == (2,2,4)
@test eltype(E) == Float64
F = similar(A, Axis{:row}())
@test size(F) == size(A)[2:end]
@test eltype(F) == eltype(A)
@test axisvalues(F) == axisvalues(A)[2:end]
@test axisnames(F) == axisnames(A)[2:end]
G = similar(A, Float64)
@test size(G) == size(A)
@test eltype(G) == Float64
@test axisvalues(A) == axisvalues(G)
@test axisnames(A) == axisnames(G)
H = similar(A, 1,1,1)
@test size(H) == (1,1,1)
@test eltype(H) == eltype(A)
@test typeof(H) <: Array
H = similar(A, Float64, 1,1,1)
@test size(H) == (1,1,1)
@test eltype(H) == Float64
@test typeof(H) <: Array


# Size
@test size(A, 1) == size(A, Axis{1}) == size(A, Axis{:row}) == size(A, Axis{:row}())

## Test constructors
# No axis or time args
A = AxisArray(1:3)
@test A.data == 1:3
@test axisnames(A) == (:row,)
VERSION >= v"0.5.0-dev" && @inferred(axisnames(A))
@test axisvalues(A) == (1:3,)
A = AxisArray(reshape(1:16, 2,2,2,2))
@test A.data == reshape(1:16, 2,2,2,2)
@test axisnames(A) == (:row,:col,:page,:dim_4)
VERSION >= v"0.5.0-dev" && @inferred(axisnames(A))
@test axisvalues(A) == (1:2, 1:2, 1:2, 1:2)
# Just axis names
A = AxisArray(1:3, :a)
@test A.data == 1:3
@test axisnames(A) == (:a,)
VERSION >= v"0.5.0-dev" && @inferred(axisnames(A))
@test axisvalues(A) == (1:3,)
A = AxisArray([1 3; 2 4], :a)
@test A.data == [1 3; 2 4]
@test axisnames(A) == (:a, :col)
VERSION >= v"0.5.0-dev" && @inferred(axisnames(A))
@test axisvalues(A) == (1:2, 1:2)
# Just axis values
A = AxisArray(1:3, .1:.1:.3)
@test A.data == 1:3
@test axisnames(A) == (:row,)
VERSION >= v"0.5.0-dev" && @inferred(axisnames(A))
@test axisvalues(A) == (.1:.1:.3,)
A = AxisArray(reshape(1:16, 2,2,2,2), .5:.5:1)
@test A.data == reshape(1:16, 2,2,2,2)
@test axisnames(A) == (:row,:col,:page,:dim_4)
VERSION >= v"0.5.0-dev" && @inferred(axisnames(A))
@test axisvalues(A) == (.5:.5:1, 1:2, 1:2, 1:2)

# Test axisdim
@test_throws ArgumentError AxisArray(reshape(1:24, 2,3,4),
                                     Axis{1}(.1:.1:.2),
                                     Axis{2}(1//10:1//10:3//10),
                                     Axis{3}(["a", "b", "c", "d"])) # Axis need to be symbols

A = AxisArray(reshape(1:24, 2,3,4),
              Axis{:x}(.1:.1:.2),
              Axis{:y}(1//10:1//10:3//10),
              Axis{:z}(["a", "b", "c", "d"]))

@test axisdim(A, Axis{:x}) == axisdim(A, Axis{:x}()) == 1
@test axisdim(A, Axis{:y}) == axisdim(A, Axis{:y}()) == 2
@test axisdim(A, Axis{:z}) == axisdim(A, Axis{:z}()) == 3
# Test axes
@test @inferred(axes(A)) == (Axis{:x}(.1:.1:.2), Axis{:y}(1//10:1//10:3//10), Axis{:z}(["a", "b", "c", "d"]))
@test @inferred(axes(A, Axis{:x})) == @inferred(axes(A, Axis{:x}())) == Axis{:x}(.1:.1:.2)
@test @inferred(axes(A, Axis{:y})) == @inferred(axes(A, Axis{:y}())) == Axis{:y}(1//10:1//10:3//10)
@test @inferred(axes(A, Axis{:z})) == @inferred(axes(A, Axis{:z}())) == Axis{:z}(["a", "b", "c", "d"])

@test Axis{:col}(1) == Axis{:col}(1)
@test Axis{:col}(1) != Axis{:com}(1)
@test hash(Axis{:col}(1)) == hash(Axis{:col}(1.0))
@test hash(Axis{:row}()) != hash(Axis{:col}())
@test AxisArrays.axistype(Axis{1}(1:2)) == typeof(1:2)
@test axisnames(Axis{1}, Axis{2}, Axis{3}) == (1,2,3)

# Test Timetype axis construction
dt, vals = DateTime(2010, 1, 2, 3, 40), randn(5,2)
A = AxisArray(vals, Axis{:Timestamp}(dt-Dates.Hour(2):Dates.Hour(1):dt+Dates.Hour(2)), Axis{:Cols}([:A, :B]))
@test A[:, :A].data == vals[:, 1]
@test A[dt, :].data == vals[3, :]

# Simply run the display method to ensure no stupid errors
@compat show(IOBuffer(),MIME("text/plain"),A)
