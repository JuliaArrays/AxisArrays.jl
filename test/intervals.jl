# Specific intervals tests

# Promotion behaviors -- we only allow concrete endpoints of the same type
@test 1.0 .. 2 === 1.0 .. 2.0
@test 1//2 .. 3.5 === 0.5 .. 3.5
@test_throws ArgumentError :a .. "b"
@test_throws ArgumentError 1 .. (2,3)

v = [1 .. 2, 3.0 .. 4.0]
@test v[1] === 1.0 .. 2.0
@test v[2] === 3.0 .. 4.0

# Test simple arithmetic, with promotion behaviors
@test (1.0 .. 2.0) + 1 === (2.0 .. 3.0)
@test (1 .. 2) + 1.0 === (2.0 .. 3.0)
@test (1 .. 2) + (1.0 .. 2.0) === (2.0 .. 4.0)
@test (1 .. 2) - (1 .. 2) === (-1 .. 1)
@test +(1 .. 2) === (1 .. 2)
@test -(1 .. 2) === (-2 .. -1)

@test (1..2)*3 === 3..6
@test (-1..1)*3 === -3..3
@test (2..4)/2 === 1.0 .. 2.0
@test 1/(2..4) === 1/4 .. 1/2

@test 3.2 in 3..4
@test 4 in 2.0 .. 6.0
@test 4 in 4.0 .. 4.0
@test 4 in 4.0 .. 5
@test (1..2) in (0.5 .. 2.5)
@test !((1..2) in (1.5 .. 2.5))

@test maximum(1..2) === 2
@test minimum(1..2) === 1

# Comparisons are "for-all" like, with <= and >= allowing overlap
@test   0 <= 1 .. 2
@test !(0 >= 1 .. 2)
@test   1 <= 1 .. 2
@test !(1 >= 1 .. 2)
@test !(2 <= 1 .. 2)
@test   2 >= 1 .. 2
@test !(3 <= 1 .. 2)
@test   3 >= 1 .. 2

@test   0 < 1 .. 2
@test !(0 > 1 .. 2)
@test !(1 < 1 .. 2)
@test !(1 > 1 .. 2)
@test !(2 < 1 .. 2)
@test !(2 > 1 .. 2)
@test !(3 < 1 .. 2)
@test   3 > 1 .. 2

# Test dictionary lookup by numeric value
d = Dict(1..2 => 1, 2.0..3.0 => 2)
@test d[1..2] === 1
@test d[1.0..2.0] === 1
@test d[2..3] === 2
@test d[2.0..3.0] === 2
d[0x1 .. 0x2] = 3
@test d[1..2] === 3
@test length(d) == 2

# Test repeated intervals:
@test (1..2) + [1,2,3] == [(1..2)+i for i in [1,2,3]]
@test (1..2) + (1:3) == [(1..2)+i for i in 1:3]
@test (1..2) - [1,2,3] == [(1..2)-i for i in [1,2,3]]
@test (1..2) - (1:3) == [(1..2)-i for i in 1:3]

@test [1,2,3] + (1..2)== [i+(1..2) for i in [1,2,3]]
@test (1:3) + (1..2)== [i+(1..2) for i in 1:3]
@test [1,2,3] - (1..2)== [i-(1..2) for i in [1,2,3]]
@test (1:3) - (1..2)== [i-(1..2) for i in 1:3]

# And intervals at indices
@test atindex(1..2, [3,4,5]) == [atindex(1..2, i) for i in [3,4,5]]
@test atindex(1..2, 3:5) == [atindex(1..2, i) for i in 3:5]

# Ensure comparisons are exact (and not lossy)
@assert 0.2 > 2//10 # 0.2 == 2.0000000000000001
@test !(0.1 .. 0.2 <= 2//10)

# Conversion and construction:
@test 1 .. 2 === ClosedInterval(1, 2) === ClosedInterval{Int}(1.0, 2.0) === ClosedInterval{Int}(1.0 .. 2.0)
@test 1.0 .. 2.0 === ClosedInterval(1.0, 2) === ClosedInterval{Float64}(1, 2) === ClosedInterval{Float64}(1 .. 2)
@test 1 .. 1 === ClosedInterval(1, 1) === ClosedInterval{Int}(1.0, 1.0)
