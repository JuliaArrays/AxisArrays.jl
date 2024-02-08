A0 = [1,2,3]
A  = AxisArray(A0, Axis{:abc}([1.0, 2.0, 3.0]))
A1 = AxisArray(A0, Axis{:def}([1.0, 2.0, 3.0]))
A2 = AxisArray(A0, Axis{:abc}([1.0, 2.0, 3.0+eps(3.0)]))

B0 = [1 2 3]
B  = AxisArray(B0, Axis{:row}(Base.OneTo(1)), Axis{:def}([1.3, 2.4, 36]))
B1 = AxisArray(B0, Axis{:row}(Base.OneTo(1)),  Axis{:abc}([1.0, 2.0, 3.0]))
B2 = AxisArray(B0, Axis{:abc}(Base.OneTo(1)), Axis{:def}([1.3, 2.4, 36]))

C0 = reshape([10])
C  = AxisArray(C0)

D0 = ones(Complex, 3, 3)
D  = AxisArray(D0, Axis{:abc}([1.0, 2.0, 3.0]), Axis{:def}([1.3, 2.4, 36]))
D1 = AxisArray(D0, Axis{:abc}([1.0, 2.0, 3.0+eps(3.0)]), Axis{:def}([1.3, 2.4, 36]))
D2 = AxisArray(D0, Axis{:row}(Base.OneTo(3)), Axis{:def}([1.3, 2.4, 36]))
D3 = AxisArray(D0, Axis{:abc}([1.0, 2.0, 3.1]), Axis{:def}([1.3, 2.4, 36]))

# AxisArray 0-d + number
@test (C .+ 1) isa AxisArray
@test @inferred(C .+ 1).data == reshape([11])
@test AxisArrays.axes(C .+ 1) == ()
@test (1 .+ C) isa AxisArray
@test @inferred(1 .+ C).data == reshape([11])
@test AxisArrays.axes(1 .+ C) == ()

# AxisArray vector + number
@test (A .+ 1) isa AxisArray
@test @inferred(A .+ 1).data == [2,3,4]
@test AxisArrays.axes(A .+ 1)[1] == Axis{:abc}([1.0, 2.0, 3.0])
@test (1 .+ A) isa AxisArray
@test @inferred(1 .+ A).data == [2,3,4]
@test AxisArrays.axes(1 .+ A)[1] == Axis{:abc}([1.0, 2.0, 3.0])

# AxisArray row-vector + number...
# AxisArray matrix + number...
# AxisArray higher-d + number...

# AxisArray 0-d + AxisArray 0-d
@test (C .+ C) isa AxisArray
@test @inferred(C .+ C).data == reshape([20])
@test AxisArrays.axes(C .+ C) == ()

# AxisArray 0-d + non-AxisArray 0-d
@test (C0 .+ C) isa AxisArray
@test @inferred(C0 .+ C).data == reshape([20])
@test AxisArrays.axes(C0 .+ C) == ()
@test (C .+ C0) isa AxisArray
@test @inferred(C .+ C0).data == reshape([20])
@test AxisArrays.axes(C .+ C0) == ()

# AxisArray vector + AxisArray 0-d
@test @inferred(A .+ C).data == [11,12,13]
@test AxisArrays.axes(A .+ C)[1] == Axis{:abc}([1.0, 2.0, 3.0])
@test length(AxisArrays.axes(A .+ C)) == 1
@test @inferred(C .+ A).data == [11,12,13]
@test AxisArrays.axes(C .+ A)[1] == Axis{:abc}([1.0, 2.0, 3.0])
@test length(AxisArrays.axes(C .+ A)) == 1

# AxisArray vector + non-AxisArray 0-d
@test @inferred(A .+ C0).data == [11,12,13]
@test AxisArrays.axes(A .+ C0)[1] == Axis{:abc}([1.0, 2.0, 3.0])
@test length(AxisArrays.axes(A .+ C0)) == 1
@test @inferred(C0 .+ A).data == [11,12,13]
@test AxisArrays.axes(C0 .+ A)[1] == Axis{:abc}([1.0, 2.0, 3.0])
@test length(AxisArrays.axes(C0 .+ A)) == 1

# AxisArray vector + AxisArray vector
@test @inferred(A .+ A).data == [2,4,6]
@test AxisArrays.axes(A .+ A)[1] == Axis{:abc}([1.0, 2.0, 3.0])
@test length(AxisArrays.axes(A .+ A)) == 1
@test_throws DimensionMismatch (A.+A1)      # axis name mismatch
@test_throws DimensionMismatch (A1.+A)
@test_throws DimensionMismatch (A.+A2)      # axis value mismatch (floating-points count)
@test_throws DimensionMismatch (A2.+A)

# AxisArray vector + non-AxisArray vector
@test @inferred(A .+ A0).data == [2,4,6]
@test AxisArrays.axes(A .+ A0)[1] == Axis{:abc}([1.0, 2.0, 3.0])
@test length(AxisArrays.axes(A .+ A0)) == 1
@test @inferred(A0 .+ A).data == [2,4,6]
@test AxisArrays.axes(A0 .+ A)[1] == Axis{:abc}([1.0, 2.0, 3.0])
@test length(AxisArrays.axes(A0 .+ A)) == 1

# AxisArray vector + 1xN AxisArray matrix
@test_broken @inferred(A .+ B).data == [2 3 4; 3 4 5; 4 5 6]   # output good but axes aren't yet inferred...
@test length(AxisArrays.axes(A .+ B)) == 2
@test AxisArrays.axes(A .+ B)[1] == Axis{:abc}([1.0, 2.0, 3.0])
@test AxisArrays.axes(A .+ B)[2] == Axis{:def}([1.3, 2.4, 36])

@test_broken @inferred(B .+ A).data == [2 3 4; 3 4 5; 4 5 6]   # output good but axes aren't yet inferred...
@test length(AxisArrays.axes(B .+ A)) == 2
@test AxisArrays.axes(B .+ A)[1] == Axis{:abc}([1.0, 2.0, 3.0])
@test AxisArrays.axes(B .+ A)[2] == Axis{:def}([1.3, 2.4, 36])

@test_throws ArgumentError (A.+B1)  # axis names don't match
@test_throws ArgumentError (B1.+A)
@test_broken @test_throws DimensionMismatch (A.+B2)
@test_broken @test_throws DimensionMismatch (B2.+A)

# AxisArray vector + 1xN non-AxisArray matrix
@test @inferred(A.+B0).data == [2 3 4; 3 4 5; 4 5 6]
@test length(AxisArrays.axes(A .+ B0)) == 2
@test AxisArrays.axes(A .+ B0)[1] == Axis{:abc}([1.0, 2.0, 3.0])
@test AxisArrays.axes(A .+ B0)[2] == Axis{:col}(Base.OneTo(3))

# AxisArray vector + NxN AxisArray matrix
@test_broken @inferred(A .+ D).data ==
    [2+0im 2+0im 2+0im;
     3+0im 3+0im 3+0im;
     4+0im 4+0im 4+0im] # output good but inference dies
@test length(AxisArrays.axes(A .+ D)) == 2
@test AxisArrays.axes(A .+ D)[1] == Axis{:abc}([1.0, 2.0, 3.0])
@test AxisArrays.axes(A .+ D)[2] == Axis{:def}([1.3, 2.4, 36])
@test_broken @inferred(D .+ A).data ==
    [2+0im 2+0im 2+0im;
     3+0im 3+0im 3+0im;
     4+0im 4+0im 4+0im] # output good but inference dies
@test length(AxisArrays.axes(D .+ A)) == 2
@test AxisArrays.axes(D .+ A)[1] == Axis{:abc}([1.0, 2.0, 3.0])
@test AxisArrays.axes(D .+ A)[2] == Axis{:def}([1.3, 2.4, 36])
@test_throws DimensionMismatch (A.+D1)
@test_throws DimensionMismatch (D1.+A)
@test_throws DimensionMismatch (A.+D2)
@test_throws DimensionMismatch (D2.+A)
@test_throws DimensionMismatch (A.+D3)
@test_throws DimensionMismatch (D3.+A)

# AxisArray vector + NxN non-AxisArray matrix
@test_broken @inferred(A .+ D0).data ==
    [2+0im 2+0im 2+0im;
     3+0im 3+0im 3+0im;
     4+0im 4+0im 4+0im] # output good but inference dies
@test length(AxisArrays.axes(A .+ D0)) == 2
@test AxisArrays.axes(A .+ D0)[1] == Axis{:abc}([1.0, 2.0, 3.0])
@test AxisArrays.axes(A .+ D0)[2] == Axis{:col}(Base.OneTo(3))
@test_broken @inferred(D0 .+ A).data ==
    [2+0im 2+0im 2+0im;
     3+0im 3+0im 3+0im;
     4+0im 4+0im 4+0im] # output good but inference dies
@test length(AxisArrays.axes(D0 .+ A)) == 2
@test AxisArrays.axes(D0 .+ A)[1] == Axis{:abc}([1.0, 2.0, 3.0])
@test AxisArrays.axes(D0 .+ A)[2] == Axis{:col}(Base.OneTo(3))
