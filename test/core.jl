# FIXME: type stability broken. The following should NOT error
A = @inferred(AxisArray(reshape(1:24, 2,3,4), .1:.1:.2, .1:.1:.3, .1:.1:.4))
@test_throws ArgumentError AxisArray(reshape(1:24, 2,3,4), .1:.1:.1, .1:.1:.3, .1:.1:.4)
@test_throws ArgumentError AxisArray(reshape(1:24, 2,3,4), .1:.1:.1, .1:.1:.3)
@test_throws ArgumentError AxisArray(reshape(1:24, 2,3,4), .1:.1:.2, .1:.1:.3, .1:.1:.4, 1:1)
@test parent(A) === reshape(1:24, 2,3,4)
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

# permutedims and transpose
@test axisnames(permutedims(A, (2,1,3))) == (:col, :row, :page)
@test axisnames(permutedims(A, (2,3,1))) == (:col, :page, :row)
@test axisnames(permutedims(A, (3,2,1))) == (:page, :col, :row)
@test axisnames(permutedims(A, (3,1,2))) == (:page, :row, :col)
for perm in ((:col, :row, :page), (:col, :page, :row),
             (:page, :col, :row), (:page, :row, :col),
             (:row, :page, :col), (:row, :col, :page))
    @test axisnames(permutedims(A, perm)) == perm
end
@test axisnames(permutedims(A, (:col,)))  == (:col, :row, :page)
@test axisnames(permutedims(A, (:page,))) == (:page, :row, :col)
A2 = @inferred(AxisArray(reshape(1:15, 3, 5)))
A1 = AxisArray(1:5, :t)
for f in (transpose, adjoint)
    @test f(A2).data == f(A2.data)
    @test axisnames(f(A2)) == (:col, :row)
    @test f(A1).data == f(A1.data)
    @test axisnames(f(A1)) == (:transpose, :t)
end

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
@inferred(axisnames(A))
@test axisvalues(A) == (1:3,)
A = AxisArray(reshape(1:16, 2,2,2,2))
@test A.data == reshape(1:16, 2,2,2,2)
@test axisnames(A) == (:row,:col,:page,:dim_4)
@inferred(axisnames(A))
@test axisvalues(A) == (1:2, 1:2, 1:2, 1:2)
# Just axis names
A = AxisArray(1:3, :a)
@test A.data == 1:3
@test axisnames(A) == (:a,)
@inferred(axisnames(A))
@test axisvalues(A) == (1:3,)
A = AxisArray([1 3; 2 4], :a)
@test A.data == [1 3; 2 4]
@test axisnames(A) == (:a, :col)
@inferred(axisnames(A))
@test axisvalues(A) == (1:2, 1:2)
# Just axis values
A = @inferred(AxisArray(1:3, .1:.1:.3))
@test A.data == 1:3
@test axisnames(A) == (:row,)
@inferred(axisnames(A))
@test axisvalues(A) == (.1:.1:.3,)
# FIXME: reintroduce inferred
A = @inferred(AxisArray(reshape(1:16, 2,2,2,2), .5:.5:1))
@test A.data == reshape(1:16, 2,2,2,2)
@test axisnames(A) == (:row,:col,:page,:dim_4)
@inferred(axisnames(A))
@test axisvalues(A) == (.5:.5:1, 1:2, 1:2, 1:2)
A = AxisArray([0]', :x, :y)
@test axisnames(dropdims(A, dims=1)) == (:y,)
@test axisnames(dropdims(A, dims=2)) == (:x,)
@test axisnames(dropdims(A, dims=(1,2))) == axisnames(dropdims(A, dims=(2,1))) == ()
@test axisnames((dropdims(A, dims=Axis{:x}))) == (:y,)
@test axisnames((dropdims(A, dims=Axis{:x,UnitRange{Int}}))) == (:y,)
@test axisnames((dropdims(A, dims=Axis{:y}))) == (:x,)
@test axisnames((dropdims(dropdims(A, dims=Axis{:x}), dims=Axis{:y}))) == ()
@test_broken @inferred(dropdims(A, dims=Axis{:x}))
@test_broken @inferred(dropdims(A, dims=Axis{:x,UnitRange{Int}}))
@test_broken @inferred(dropdims(A, dims=Axis{:y}))
@test_broken @inferred(dropdims(dropdims(A, dims=Axis{:x}), dims=Axis{:y}))
# Names, steps, and offsets
B = AxisArray([1 4; 2 5; 3 6], (:x, :y), (0.2, 100))
@test axisnames(B) == (:x, :y)
@test axisvalues(B) == (0:0.2:0.4, 0:100:100)
B = AxisArray([1 4; 2 5; 3 6], (:x, :y), (0.2, 100), (-3,14))
@test axisnames(B) == (:x, :y)
@test axisvalues(B) == (-3:0.2:-2.6, 14:100:114)

@test AxisArrays.HasAxes(A)   == AxisArrays.HasAxes{true}()
@test AxisArrays.HasAxes([1]) == AxisArrays.HasAxes{false}()

@test_throws ArgumentError AxisArray(reshape(1:24, 2,3,4),
                                     Axis{1}(.1:.1:.2),
                                     Axis{2}(1//10:1//10:3//10),
                                     Axis{3}(["a", "b", "c", "d"])) # Axis need to be symbols
@test_throws ArgumentError AxisArray(reshape(1:24, 2,3,4),
                                     Axis{:x}(.1:.1:.2),
                                     Axis{:y}(1//10:1//10:3//10),
                                     Axis{:z}(["a", "b", "c", "d"]),
                                     Axis{:_}(1:1)) # Too many Axes

A = @inferred(AxisArray(reshape(1:24, 2,3,4),
              Axis{:x}(.1:.1:.2),
              Axis{:y}(1//10:1//10:3//10),
              Axis{:z}(["a", "b", "c", "d"])))

# recursive constructor
@test A === @inferred AxisArray(A)
@test axisnames(AxisArray(A, Axis{:yoyo}(1:length(A[Axis{:x}])))) == (:yoyo, :y, :z)
@test AxisArray(A, Axis{:yoyo}(1:length(A[Axis{:x}]))).data === A.data
@test AxisArray(A, (Axis{:yoyo}(1:length(A[Axis{:x}])),)).data === A.data
@test axisnames(AxisArray(A, :something, :in, :the)) == (:something, :in, :the)
@test AxisArray(A, :way, :you, :move).data === A.data
@test axisnames(AxisArray(A, (:c, :a, :b), (2, 3, 4))) == (:c, :a, :b)
@test AxisArray(A, (:c, :a, :b), (2, 3, 4)).data === A.data
@inferred AxisArray(A, Axis{:yoyo}(1:length(A[Axis{:x}])))
@inferred AxisArray(A, (Axis{:yoyo}(1:length(A[Axis{:x}])),))

# Test axisdim
@test axisdim(A, Axis{:x}) == axisdim(A, Axis{:x}()) == 1
@test axisdim(A, Axis{:y}) == axisdim(A, Axis{:y}()) == 2
@test axisdim(A, Axis{:z}) == axisdim(A, Axis{:z}()) == 3
# Test axes
@test @inferred(AxisArrays.axes(A)) == (Axis{:x}(.1:.1:.2), Axis{:y}(1//10:1//10:3//10), Axis{:z}(["a", "b", "c", "d"]))
@test @inferred(AxisArrays.axes(A, Axis{:x})) == @inferred(AxisArrays.axes(A, Axis{:x}())) == Axis{:x}(.1:.1:.2)
@test @inferred(AxisArrays.axes(A, Axis{:y})) == @inferred(AxisArrays.axes(A, Axis{:y}())) == Axis{:y}(1//10:1//10:3//10)
@test @inferred(AxisArrays.axes(A, Axis{:z})) == @inferred(AxisArrays.axes(A, Axis{:z}())) == Axis{:z}(["a", "b", "c", "d"])
@test AxisArrays.axes(A, 2) == Axis{:y}(1//10:1//10:3//10)
Aplain = rand(2,3)
@test @inferred(AxisArrays.axes(Aplain)) === AxisArrays.axes(AxisArray(Aplain))
@test AxisArrays.axes(Aplain, 1) === AxisArrays.axes(AxisArray(Aplain))[1]
@test AxisArrays.axes(Aplain, 2) === AxisArrays.axes(AxisArray(Aplain))[2]

@test Axis{:col}(1) == Axis{:col}(1)
@test Axis{:col}(1) != Axis{:com}(1)
@test Axis{:x}(1:3) == Axis{:x}(Base.OneTo(3))
@test hash(Axis{:col}(1)) == hash(Axis{:col}(1.0))
@test hash(Axis{:row}()) != hash(Axis{:col}())
@test hash(Axis{:x}(1:3)) == hash(Axis{:x}(Base.OneTo(3)))
@test AxisArrays.axistype(Axis{1}(1:2)) == typeof(1:2)
@test AxisArrays.axistype(Axis{1,UInt32}) == UInt32
@test axisnames(Axis{1}, Axis{2}, Axis{3}) == (1,2,3)
@test Axis{:row}(2:7)[4] == 5
@test eltype(Axis{:row}(1.0:1.0:3.0)) == Float64
@test size(Axis{:row}(2:7)) === (6,)
T = A[AxisArrays.Axis{:x}]
@test T[end] == 0.2
@test Base.axes(Axis{:row}(2:7)) === (Base.OneTo(6),)
@test Base.axes(Axis{:row}(-1:1), 1) === Base.OneTo(3)
@test length(Axis{:col}(-1:2)) === 4
@test AxisArrays.axisname(Axis{:foo}(1:2)) == :foo
@test AxisArrays.axisname(Axis{:foo})      == :foo

# Test Timetype axis construction
dt, vals = DateTime(2010, 1, 2, 3, 40), randn(5,2)
A = @inferred(AxisArray(vals, Axis{:Timestamp}(dt-Dates.Hour(2):Dates.Hour(1):dt+Dates.Hour(2)), Axis{:Cols}([:A, :B])))
@test A[:, :A].data == vals[:, 1]
@test A[dt, :].data == vals[3, :]

@test AxisArrays.axistrait(A.axes[1]) == AxisArrays.Dimensional
@test AxisArrays.axistrait(typeof(A.axes[1])) == AxisArrays.Dimensional
@test AxisArrays.axistrait(A.axes[1].val) == AxisArrays.Dimensional
@test AxisArrays.axistrait(typeof(A.axes[1].val)) == AxisArrays.Dimensional
@test AxisArrays.axistrait(A.axes[2]) == AxisArrays.Categorical
@test AxisArrays.axistrait(typeof(A.axes[2])) == AxisArrays.Categorical
@test AxisArrays.axistrait(A.axes[2].val) == AxisArrays.Categorical
@test AxisArrays.axistrait(typeof(A.axes[2].val)) == AxisArrays.Categorical

@test_throws ArgumentError AxisArrays.checkaxis(Axis{:x}(10:-1:1))
@test_throws ArgumentError AxisArrays.checkaxis(10:-1:1)

# Simply run the display method to ensure no stupid errors
show(IOBuffer(),MIME("text/plain"),A)

# With unconventional indices
import OffsetArrays  # import rather than using because OffsetArrays has a deprecation for ..
A = AxisArray(OffsetArrays.OffsetArray([5,3,4], -1:1), :x)
@test AxisArrays.axes(A) == (Axis{:x}(-1:1),)
@test A[-1] == 5
A[0] = 12
@test A.data[0] == 12
@test Base.axes(A) == Base.axes(A.data)
@test LinearIndices(A) == LinearIndices(A.data)
A = AxisArray(OffsetArrays.OffsetArray(rand(4,5), -1:2, 5:9), :x, :y)
@test Base.axes(A) == Base.axes(A.data)
@test LinearIndices(A) == LinearIndices(A.data)

@test AxisArrays.matchingdims((A, A))

f1(x) = x < 0
A2 = map(f1, A)
@test isa(A2, AxisArray)
@test A2.axes == A.axes
@test A2.data == map(f1, A.data)

map!(~, A2, A2)
@test isa(A2, AxisArray)
@test A2.axes == A.axes
@test A2.data == map(~, map(f1, A).data)

A2 = map(+, A, A)
@test isa(A2, AxisArray)
@test A2.axes == A.axes
@test A2.data == A.data .+ A.data

map!(*, A2, A, A)
@test isa(A2, AxisArray)
@test A2.axes == A.axes
@test A2.data == A.data .* A.data

# Reductions (issue #55)
A = AxisArray(collect(reshape(1:15,3,5)), :y, :x)
B = @inferred(AxisArray(collect(reshape(1:15,3,5)), Axis{:y}(0.1:0.1:0.3), Axis{:x}(10:10:50)))
arrays = (A, B)
functions = (sum, minimum)
for C in arrays
    local C
    for op in functions  # together, cover both reduced_indices and reduced_indices0
        axv = axisvalues(C)
        @test_broken @inferred(op(C; dims=1))
        C1 = op(C; dims=1)
        @test typeof(C1) == typeof(C)
        @test axisnames(C1) == (:y,:x)
        @test axisvalues(C1) === (oftype(axv[1], Base.OneTo(1)), axv[2])
        @test_broken @inferred(op(C, dims=2))
        C2 = op(C, dims=2)
        @test typeof(C2) == typeof(C)
        @test axisnames(C2) == (:y,:x)
        @test axisvalues(C2) === (axv[1], oftype(axv[2], Base.OneTo(1)))
        @test_broken @inferred(op(C, dims=(1,2)))
        C12 = op(C, dims=(1,2))
        @test typeof(C12) == typeof(C)
        @test axisnames(C12) == (:y,:x)
        @test axisvalues(C12) === (oftype(axv[1], Base.OneTo(1)), oftype(axv[2], Base.OneTo(1)))
        if op == sum
            @test C1 == [6 15 24 33 42]
            @test C2 == reshape([35,40,45], 3, 1)
            @test C12 == reshape([120], 1, 1)
        else
            @test C1 == [1 4 7 10 13]
            @test C2 == reshape([1,2,3], 3, 1)
            @test C12 == reshape([1], 1, 1)
        end
        # TODO: add @inferred
        @test (op(C, dims=Axis{:y})) == C1
        @test (op(C, dims=Axis{:x})) == C2
        @test (op(C, dims=(Axis{:y},Axis{:x}))) == C12
        @test (op(C, dims=Axis{:y}())) == C1
        @test (op(C, dims=Axis{:x}())) == C2
        @test (op(C, dims=(Axis{:y}(),Axis{:x}()))) == C12
    end
end

function typeof_noaxis(::AxisArray{T,N,D}) where {T,N,D}
    AxisArray{T,N,D}
end

# uninferrable
C = AxisArray(collect(reshape(1:15,3,5)), Axis{:y}([:a,:b,:c]), Axis{:x}(["a","b","c","d","e"]))
for op in functions  # together, cover both reduced_indices and reduced_indices0
    axv = axisvalues(C)
    C1 = op(C, dims=1)
    @test typeof_noaxis(C1) == typeof_noaxis(C)
    @test axisnames(C1) == (:y,:x)
    @test axisvalues(C1) === (Base.OneTo(1), axv[2])
    C2 = op(C, dims=2)
    @test typeof_noaxis(C2) == typeof_noaxis(C)
    @test axisnames(C2) == (:y,:x)
    @test axisvalues(C2) === (axv[1], Base.OneTo(1))
    C12 = op(C, dims=(1,2))
    @test typeof_noaxis(C12) == typeof_noaxis(C)
    @test axisnames(C12) == (:y,:x)
    @test axisvalues(C12) === (Base.OneTo(1), Base.OneTo(1))
    if op == sum
        @test C1 == [6 15 24 33 42]
        @test C2 == reshape([35,40,45], 3, 1)
        @test C12 == reshape([120], 1, 1)
    else
        @test C1 == [1 4 7 10 13]
        @test C2 == reshape([1,2,3], 3, 1)
        @test C12 == reshape([1], 1, 1)
    end
    # TODO: These should be @inferred, but are currently broken
    @test (op(C, dims=Axis{:y})) == C1
    @test (op(C, dims=Axis{:x})) == C2
    # Unfortunately the type of (Axis{:y},Axis{:x}) is Tuple{UnionAll,UnionAll} so methods will not specialize
    @test (op(C, dims=(Axis{:y},Axis{:x}))) == C12
    @test (op(C, dims=Axis{:y}())) == C1
    @test (op(C, dims=Axis{:x}())) == C2
    @test (op(C, dims=(Axis{:y}(),Axis{:x}()))) == C12
end

C = AxisArray(collect(reshape(1:15,3,5)), Axis{:y}([:a,:b,:c]), Axis{:x}(["a","b","c","d","e"]))
@test occursin(r"axes:\n\s+:y,", summary(C))
