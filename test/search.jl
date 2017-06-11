# Internal searching methods

import AxisArrays: searchsortednearest
@test searchsortednearest(1:5, 2.5) === 3
@test searchsortednearest(1:5, prevfloat(2.5)) === 2
@test searchsortednearest([1,1,2,2,3,3], 1.5) === 3
@test searchsortednearest([1,1,2,2,3,3], 2.0) === 3
@test searchsortednearest([1,1,2,2,3,3], 2.4) === 4
@test searchsortednearest([1,1,2,2,3,3], 3.0) === 5
@test searchsortednearest([1,1,2,2,3,3], Inf) === 6
@test searchsortednearest([1,1,2,2,3,3], -Inf) === 1

# Extrapolated searching for ranges
import AxisArrays: Extrapolated
@test Extrapolated.searchsorted(1:10, -1 .. 1) === -1:1
@test Extrapolated.searchsorted(1:10, 12 .. 15) === 12:15
@test Extrapolated.searchsorted(0:2:10, -3 .. -1) === 0:0
@test Extrapolated.searchsorted(0:2:10, -5 .. 3) === -1:2

@test Extrapolated.searchsorted(1:2, 4.5 .. 4.5) === 5:4
@test Extrapolated.searchsorted(1:2, 3.5 .. 3.5) === 4:3
@test Extrapolated.searchsorted(1:2, 2.5 .. 2.5) === 3:2 === searchsorted(1:2, 2.5 .. 2.5)
@test Extrapolated.searchsorted(1:2, 1.5 .. 1.5) === 2:1 === searchsorted(1:2, 1.5 .. 1.5)
@test Extrapolated.searchsorted(1:2, 0.5 .. 0.5) === 1:0 === searchsorted(1:2, 0.5 .. 0.5)
@test Extrapolated.searchsorted(1:2, -0.5 .. -0.5) === 0:-1
@test Extrapolated.searchsorted(1:2, -1.5 .. -1.5) === -1:-2

@test Extrapolated.searchsorted(2:2:4, 0x6 .. 0x6) === 3:3
@test Extrapolated.searchsorted(2:2:4, 0x5 .. 0x5) === searchsorted(2:2:4, 0x5 .. 0x5) === 3:2
@test Extrapolated.searchsorted(2:2:4, 0x4 .. 0x4) === searchsorted(2:2:4, 0x4 .. 0x4) === 2:2
@test Extrapolated.searchsorted(2:2:4, 0x3 .. 0x3) === searchsorted(2:2:4, 0x3 .. 0x3) === 2:1
@test Extrapolated.searchsorted(2:2:4, 0x2 .. 0x2) === searchsorted(2:2:4, 0x2 .. 0x2) === 1:1
@test Extrapolated.searchsorted(2:2:4, 0x1 .. 0x1) === searchsorted(2:2:4, 0x1 .. 0x1) === 1:0
@test Extrapolated.searchsorted(2:2:4, 0x0 .. 0x0) === 0:0
