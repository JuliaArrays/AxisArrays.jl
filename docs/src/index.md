```@meta
DocTestSetup = quote
    using AxisArrays, Unitful, Random
    import Unitful: s, ms, µs
    rng = MersenneTwister(123)
    fs = 40000
    y = randn(rng, 60*fs+1)*3
    for spk = (sin.(0.8:0.2:8.6) .* [0:0.01:.1; .15:.1:.95; 1:-.05:.05] .* 50,
               sin.(0.8:0.4:8.6) .* [0:0.02:.1; .15:.1:1; 1:-.2:.1] .* 50)
        i = rand(rng, round(Int,.001fs):1fs)
        while i+length(spk)-1 < length(y)
            y[i:i+length(spk)-1] += spk
            i += rand(rng, round(Int,.001fs):1fs)
        end
    end
    A = AxisArray([y 2y], Axis{:time}(0s:1s/fs:60s), Axis{:chan}([:c1, :c2]))
end
```

# AxisArrays

[![Build Status](https://travis-ci.org/JuliaArrays/AxisArrays.jl.svg?branch=master)](https://travis-ci.org/JuliaArrays/AxisArrays.jl)
[![Coverage Status](https://coveralls.io/repos/github/JuliaArrays/AxisArrays.jl/badge.svg?branch=master)](https://coveralls.io/github/JuliaArrays/AxisArrays.jl?branch=master)

This package for the Julia language provides an array type (the `AxisArray`) that knows about its dimension names and axis values.
This allows for indexing with the axis name without incurring any runtime overhead.
AxisArrays can also be indexed by the values of their axes, allowing column names or interval selections.
This permits one to implement algorithms that are oblivious to the storage order of the underlying arrays.
In contrast to similar approaches in [Images.jl](https://github.com/timholy/Images.jl) and [NamedArrays.jl](https://github.com/davidavdav/NamedArrays), this allows for type-stable selection of dimensions and compile-time axis lookup.  It is also better suited for regularly sampled axes, like samples over time.

Collaboration is welcome! This is still a work-in-progress. See [the roadmap](https://github.com/JuliaArrays/AxisArrays.jl/issues/7) for the project's current direction.

## Example of currently-implemented behavior:

```julia-repl
julia> Pkg.add("AxisArrays")
julia> using AxisArrays, Unitful, Random
julia> import Unitful: s, ms, µs

julia> rng = MersenneTwister(123) # Seed a random number generator for repeatable examples
julia> fs = 40000 # Generate a 40kHz noisy signal, with spike-like stuff added for testing
julia> y = randn(rng, 60*fs+1)*3
julia> for spk = (sin.(0.8:0.2:8.6) .* [0:0.01:.1; .15:.1:.95; 1:-.05:.05] .* 50,
                  sin.(0.8:0.4:8.6) .* [0:0.02:.1; .15:.1:1; 1:-.2:.1] .* 50)
           i = rand(rng, round(Int,.001fs):1fs)
           while i+length(spk)-1 < length(y)
               y[i:i+length(spk)-1] += spk
               i += rand(rng, round(Int,.001fs):1fs)
           end
       end
```

```jldoctest
julia> A = AxisArray([y 2y], Axis{:time}(0s:1s/fs:60s), Axis{:chan}([:c1, :c2]))
2-dimensional AxisArray{Float64,2,...} with axes:
    :time, (0.0:2.5e-5:60.0) s
    :chan, [:c1, :c2]
And data, a 2400001×2 Matrix{Float64}:
  0.970572    1.94114
 -5.70694   -11.4139
  0.46122     0.92244
 -1.5859     -3.17181
  2.17776     4.35552
 -5.12439   -10.2488
  2.79996     5.59992
  2.10746     4.21493
 -5.5069    -11.0138
  4.29289     8.58578
  ⋮
  2.05448     4.10897
 -5.12668   -10.2534
 -0.215907   -0.431814
  4.94344     9.88689
  4.55252     9.10503
  3.44757     6.89514
  2.4722      4.9444
  2.64475     5.2895
 -0.113071   -0.226143

```

AxisArrays behave like regular arrays, but they additionally use the axis
information to enable all sorts of fancy behaviors. For example, we can specify
indices in *any* order, just so long as we annotate them with the axis name:

```jldoctest
julia> A[Axis{:time}(4)]
1-dimensional AxisArray{Float64,1,...} with axes:
    :chan, [:c1, :c2]
And data, a 2-element Vector{Float64}:
 -1.5859040701220763
 -3.1718081402441527

julia> A[Axis{:chan}(:c2), Axis{:time}(1:5)]
1-dimensional AxisArray{Float64,1,...} with axes:
    :time, (0.0:2.5e-5:0.0001) s
And data, a 5-element Vector{Float64}:
   1.9411443944557378
 -11.413887226381497
   0.9224399858897993
  -3.1718081402441527
   4.3555157371883935

```

We can also index by the *values* of each axis using an `Interval` type that
selects all values between two endpoints `a .. b` or the axis values directly.
Notice that the returned AxisArray still has axis information itself... and it
still has the correct time information for those datapoints!

```jldoctest
julia> A[40µs .. 220µs, :c1]
1-dimensional AxisArray{Float64,1,...} with axes:
    :time, (5.0e-5:2.5e-5:0.0002) s
And data, a 7-element Vector{Float64}:
  0.4612199929448996
 -1.5859040701220763
  2.1777578685941967
 -5.12439070316173
  2.7999612778949685
  2.10746429190499
 -5.506904656367615

julia> AxisArrays.axes(ans, 1)
Axis{:time, StepRangeLen{Quantity{Float64, 𝐓, Unitful.FreeUnits{(s,), 𝐓, nothing}}, Base.TwicePrecision{Quantity{Float64, 𝐓, Unitful.FreeUnits{(s,), 𝐓, nothing}}}, Base.TwicePrecision{Quantity{Float64, 𝐓, Unitful.FreeUnits{(s,), 𝐓, nothing}}}, Int64}}((5.0e-5:2.5e-5:0.0002) s)

```

You can also index by a single value on an axis using `atvalue`. This will drop
a dimension. Indexing with an `Interval` type retains dimensions, even
when the ends of the interval are equal:

```jldoctest
julia> A[atvalue(2.5e-5s), :c1]
-5.706943613190749

julia> A[2.5e-5s..2.5e-5s, :c1]
1-dimensional AxisArray{Float64,1,...} with axes:
    :time, (2.5e-5:2.5e-5:2.5e-5) s
And data, a 1-element Vector{Float64}:
 -5.706943613190749

```

You can even index by multiple values by broadcasting `atvalue` over an array:

```jldoctest
julia> A[atvalue.([2.5e-5s, 75.0µs])]
2-dimensional AxisArray{Float64,2,...} with axes:
    :time, Quantity{Float64, 𝐓, Unitful.FreeUnits{(s,), 𝐓, nothing}}[2.5e-5 s, 7.5e-5 s]
    :chan, [:c1, :c2]
And data, a 2×2 Matrix{Float64}:
 -5.70694  -11.4139
 -1.5859    -3.17181

```

Sometimes, though, what we're really interested in is a window of time about a
specific index. One of the operations above (looking for values in the window from 40µs
to 220µs) might be more clearly expressed as a symmetrical window about a
specific index where we know something interesting happened. To represent this,
we use the `atindex` function:

```jldoctest
julia> A[atindex(-90µs .. 90µs, 5), :c2]
1-dimensional AxisArray{Float64,1,...} with axes:
    :time_sub, (-7.5e-5:2.5e-5:7.500000000000002e-5) s
And data, a 7-element Vector{Float64}:
 -11.413887226381497
   0.9224399858897993
  -3.1718081402441527
   4.3555157371883935
 -10.24878140632346
   5.599922555789937
   4.21492858380998

```

Note that the returned AxisArray has its time axis shifted to represent the
interval about the given index!  This simple concept can be extended to some
very powerful behaviors. For example, let's threshold our data and find windows
about those threshold crossings.

```jldoctest
julia> idxs = findall(diff(A[:,:c1] .< -15) .> 0);

julia> spks = A[atindex(-200µs .. 800µs, idxs), :c1]
2-dimensional AxisArray{Float64,2,...} with axes:
    :time_sub, (-0.0002:2.5e-5:0.0008) s
    :time_rep, Quantity{Float64, 𝐓, Unitful.FreeUnits{(s,), 𝐓, nothing}}[0.20055 s, 0.59915 s, 0.650875 s, 0.70895 s, 1.263325 s, 1.389425 s, 1.428375 s, 1.43655 s, 2.032475 s, 2.33395 s  …  57.9839 s, 58.406025 s, 58.74015 s, 58.838825 s, 59.059425 s, 59.125575 s, 59.166875 s, 59.2176 s, 59.380075 s, 59.876725 s]
And data, a 41×245 Matrix{Float64}:
   2.86123    8.26514     2.14515   …   -1.41962    -0.413538     0.993419
  -1.8017     3.12209     0.813224      -0.64579     2.85579      2.90282
   1.46148    3.81187     0.347986       3.01351     1.13241      2.248
   8.81351   -0.708326    1.25017        1.07955     3.53002     -2.37983
   4.68316    8.03222     1.61818        4.41109    -2.1597      -2.92392
   3.04843    2.27116     4.77934   …   -0.101335    2.23039      3.14383
  -5.72907    5.21333    -8.02832       -0.317973   -4.00314     -1.21328
  -2.90782   -7.01524   -12.6477        -5.24058   -10.0462      -0.43427
 -11.8745    -8.11785   -11.6229       -13.7435    -13.045       -5.46208
 -18.2097   -17.9164    -21.7609       -26.3422    -19.0823     -16.9439
   ⋮                                ⋱
   9.2757     5.04953     0.334538       0.174179    2.18744      4.68741
   3.32367    0.772247    3.98974       -1.20394     6.08171      7.80668
  -8.12102    4.83328     2.07419        0.509321   -0.0284023   -3.71894
  -6.20857    1.68384     0.525361  …   -0.238838   -1.54597     -4.42312
  -4.07384   -2.05483    -0.858261      -0.14345    -0.282987    -1.4149
  -3.30074    1.96526     1.23548       -0.146952    2.57137      0.230237
   2.12521   -1.13537     7.22253       -0.235542   -4.34315      5.48822
   1.77073    3.18589     1.61067        0.532888   -3.33085      0.522522
   4.54472    1.73379    -4.65332   …    5.93919     1.16357      0.386667

```

By indexing with a repeated interval, we have *added* a dimension to the
output! The returned AxisArray's columns specify each repetition of the
interval, and each datapoint in the column represents a timepoint within that
interval, adjusted by the time of the theshold crossing. The best part here
is that the returned matrix knows precisely where its data came from, and has
labeled its dimensions appropriately. Not only is there the proper time
base for each waveform, but we also have recorded the event times as the axis
across the columns.

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
B = AxisArray(reshape(1:15, 5, 3), .1:.1:0.5, [:a, :b, :c])
B[Axis{:row}(Interval(.2,.4))] # restrict the AxisArray along the time axis
B[Interval(0.,.3), [:a, :c]]   # select an interval and two of the columns
```

User-defined axis types can be added along with custom indexing
behaviors.

### Example: compute the intensity-weighted mean along the z axis
```julia
B = AxisArray(randn(100,100,100), :x, :y, :z)
Itotal = sumz = 0.0
for iter in eachindex(B)  # traverses in storage order for cache efficiency
    I = B[iter]  # intensity in a single voxel
    Itotal += I
    sumz += I * iter[axisdim(B, Axis{:z})]  # axisdim "looks up" the z dimension
end
meanz = sumz/Itotal
```

The intention is that all of these operations are just as efficient as they would be if you used traditional position-based indexing with all the inherent assumptions about the storage order of `B`.
