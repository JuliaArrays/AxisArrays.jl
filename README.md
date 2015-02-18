# AxisArrays

[![Build Status](https://travis-ci.org/mbauman/AxisArrays.jl.svg?branch=master)](https://travis-ci.org/mbauman/AxisArrays.jl) [![Coverage Status](https://coveralls.io/repos/mbauman/AxisArrays.jl/badge.svg?branch=master)](https://coveralls.io/r/mbauman/AxisArrays.jl?branch=master)

This package for the Julia language allows you to index arrays using names for the individual axes and keep track of dimensional axes.
This permits one to implement algorithms that are oblivious to the storage order of the underlying arrays.
In contrast to similar approaches in [Images.jl](https://github.com/timholy/Images.jl) and [NamedArrays.jl](https://github.com/davidavdav/NamedArrays),
this should enable implementation of all basic operations without introducing any runtime overhead.

See https://github.com/mbauman/Signals.jl/issues/12 for a design sketch.

## Here's what's currently implemented:

```julia
julia> using AxisArrays

julia> A = AxisArray(reshape(1:60, 12, 5), (.1:.1:1.2, .1:.1:.5))
12x5 AxisArrays.AxisArray{Int64,2,Array{Int64,2},(:row,:col),(FloatRange{Float64},FloatRange{Float64}),(Float64,Float64)}:
  1  13  25  37  49
  2  14  26  38  50
  3  15  27  39  51
  4  16  28  40  52
  5  17  29  41  53
  6  18  30  42  54
  7  19  31  43  55
  8  20  32  44  56
  9  21  33  45  57
 10  22  34  46  58
 11  23  35  47  59
 12  24  36  48  60

julia> A[Axis{:col}(2)] # grabs the second column
12-element AxisArrays.AxisArray{Int64,1,SubArray{Int64,1,Array{Int64,2},(Colon,Int64),2},(:row,),(FloatRange{Float64},),(Float64,)}:
 13
 14
 15
 16
 17
 18
 19
 20
 21
 22
 23
 24

julia> A[Axis{:row}(2)] # grabs the second column
1x5 AxisArrays.AxisArray{Int64,2,SubArray{Int64,2,Array{Int64,2},(UnitRange{Int64},Colon),2},(:row,:col),(FloatRange{Float64},FloatRange{Float64}),(Float64,Float64)}:
 2  14  26  38  50

julia> ans.axes
(0.2:0.1:0.2,0.1:0.1:0.5)

julia> A[Axis{:col}(2:5)] # grabs the second through 5th columns
12x4 AxisArrays.AxisArray{Int64,2,SubArray{Int64,2,Array{Int64,2},(Colon,UnitRange{Int64}),2},(:row,:col),(FloatRange{Float64},FloatRange{Float64}),(Float64,Float64)}:
 13  25  37  49
 14  26  38  50
 15  27  39  51
 16  28  40  52
 17  29  41  53
 18  30  42  54
 19  31  43  55
 20  32  44  56
 21  33  45  57
 22  34  46  58
 23  35  47  59
 24  36  48  60

julia> ans.axes
(0.1:0.1:1.2,0.2:0.1:0.5)

julia> A[2:5, 3:4]
4x2 AxisArrays.AxisArray{Int64,2,SubArray{Int64,2,Array{Int64,2},(UnitRange{Int64},UnitRange{Int64}),1},(:row,:col),(FloatRange{Float64},FloatRange{Float64}),(Float64,Float64)}:
 26  38
 27  39
 28  40
 29  41

julia> ans.axes
(0.2:0.1:0.5,0.3:0.1:0.4)
```

## Indexing 

### Indexing axes

Two main types of Axes supported by default include:

* Categorical axis -- These are vectors of labels, normally symbols or
  strings. Elements or slices can be selected by elements or vectors
  of elements.

* Dimensional axis -- These are sorted vectors or iterators that can
  be selected by `Intervals`. These are commonly used for sequences of
  times or date-times. For regular sample rates, ranges can be used.

Here is an example with a Dimensional axis representing a time
sequence along rows and a Categorical axis of symbols for column
headers.

```julia
B = AxisArray(reshape(1:15, 5,3), (.1:.1:0.5, [:a, :b, :c]))
A[Axis{:row}(Interval(.2,.4))] # restrict the AxisArray along the time axis
A[Interval(0.,.3), [:a, :c]]      # select an interval and two of the columns 
```

User-defined axis types can be added along with custom indexing
behaviors.

### Compute the intensity-weighted mean along the z axis
```
Itotal = sumz = 0.0
for iter in eachelement(B)  # traverses in storage order for cache efficiency
    I = B[iter]  # intensity in a single voxel
    Itotal += I
    sumz += I * iter.z  # iter.z "looks up" the current z position
end
meanz = sumz/Itotal
```

The intention is that all of these operations are just as efficient as they would be if you used traditional position-based indexing with all the inherent assumptions about the storage order of `B`.
