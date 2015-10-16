# AxisArrays

[![Build Status](https://travis-ci.org/mbauman/AxisArrays.jl.svg?branch=master)](https://travis-ci.org/mbauman/AxisArrays.jl) [![Coverage Status](https://coveralls.io/repos/mbauman/AxisArrays.jl/badge.svg?branch=master)](https://coveralls.io/r/mbauman/AxisArrays.jl?branch=master)

This package for the Julia language provides an array type (the `AxisArray`) that knows about its dimension names and axis values.
This allows for indexing with the axis name without incurring any runtime overhead.
AxisArrays can also be indexed by the values of their axes, allowing column names or interval selections.
This permits one to implement algorithms that are oblivious to the storage order of the underlying arrays.
In contrast to similar approaches in [Images.jl](https://github.com/timholy/Images.jl) and [NamedArrays.jl](https://github.com/davidavdav/NamedArrays), this allows for type-stable selection of dimensions and compile-time axis lookup.  It is also better suited for regularly sampled axes, like samples over time.

Collaboration is welcome! This is still a work-in-progress. See [the roadmap](https://github.com/mbauman/AxisArrays.jl/issues/7) for the project's current direction.

## Example of currently-implemented behavior:

```julia
julia> Pkg.clone("https://github.com/mbauman/Tuples.jl")
       Pkg.clone("https://github.com/mbauman/RangeArrays.jl")
       Pkg.clone("https://github.com/mbauman/RaggedArrays.jl")
       Pkg.clone("https://github.com/mbauman/AxisArrays.jl")
       using AxisArrays, SIUnits
       import SIUnits.ShortUnits: s, ms, µs

julia> fs = 40000 # Generate a 40kHz noisy signal, with spike-like stuff added for testing
       y = randn(60*fs+1)*3
       for spk = (sin(0.8:0.2:8.6) .* [0:0.01:.1; .15:.1:.95; 1:-.05:.05]   .* 50,
                  sin(0.8:0.4:8.6) .* [0:0.02:.1; .15:.1:1; 1:-.2:.1] .* 50)
           i = rand(round(Int,.001fs):1fs)
           while i+length(spk)-1 < length(y)
               y[i:i+length(spk)-1] += spk
               i += rand(round(Int,.001fs):1fs)
           end
       end

julia> A = AxisArray([y 2y], Axis{:time}(0s:1s/fs:60s), Axis{:chan}([:c1, :c2]))
2400001x2 AxisArrays.AxisArray{Float64,2,Array{Float64,2},Tuple{AxisArrays.Axis{:time,SIUnits.SIRange{FloatRange{Float64},Float64,0,0,1,0,0,0,0,0,0}},AxisArrays.Axis{:chan,Array{Symbol,1}}}}:
 -0.987931  -1.97586
 -0.719792  -1.43958
 -0.4038    -0.8076
 -1.12146   -2.24293
  3.31236    6.62473
 -2.38934   -4.77868
 -3.65712   -7.31424
 -1.57186   -3.14373
 -3.89403   -7.78806
 -3.48901   -6.97803
  ⋮
  1.16204    2.32408
  0.105888   0.211777
 -4.5175    -9.03501
 -0.792749  -1.5855
  1.99229    3.98458
  1.44092    2.88184
 -1.06677   -2.13353
  3.03809    6.07619
 -2.90052   -5.80104
 -0.519704  -1.03941
 ```

AxisArrays behave like regular arrays, but they additionally use the axis
information to enable all sorts of fancy behaviors. For example, we can specify
indices in *any* order, just so long as we annotate them with the axis name:

```jl
julia> A[Axis{:time}(4)]
1x2 AxisArrays.AxisArray{Float64,2,SubArray{Float64,2,Array{Float64,2},Tuple{UnitRange{Int64},Colon},2},Tuple{AxisArrays.Axis{:time,SIUnits.SIRange{FloatRange{Float64},Float64,0,0,1,0,0,0,0,0,0}},AxisArrays.Axis{:chan,Array{Symbol,1}}}}:
 -1.12146  -2.24293

julia> A[Axis{:chan}(:c2), Axis{:time}(1:5)]
5-element AxisArrays.AxisArray{Float64,1,SubArray{Float64,1,Array{Float64,2},Tuple{UnitRange{Int64},Int64},2},Tuple{AxisArrays.Axis{:time,SIUnits.SIRange{FloatRange{Float64},Float64,0,0,1,0,0,0,0,0,0}}}}:
 -1.97586
 -1.43958
 -0.8076
 -2.24293
  6.62473
```

We can also index by the *values* of each axis using an `Interval` type that
selects all values between two endpoints `a .. b` or the axis values directly.
Notice that the returned AxisArray still has axis information itself... and it
still has the correct time information for those datapoints!

```jl
julia> A[40µs .. 220µs, :c1]
7-element AxisArrays.AxisArray{Float64,1,SubArray{Float64,1,Array{Float64,2},Tuple{UnitRange{Int64},Int64},2},Tuple{AxisArrays.Axis{:time,SIUnits.SIRange{FloatRange{Float64},Float64,0,0,1,0,0,0,0,0,0}}}}:
 -0.4038
 -1.12146
  3.31236
 -2.38934
 -3.65712
 -1.57186
 -3.89403

julia> axes(ans, 1)
AxisArrays.Axis{:time,SIUnits.SIRange{FloatRange{Float64},Float64,0,0,1,0,0,0,0,0,0}}(5.0e-5 s:2.5e-5 s:0.00015 s)
```

Sometimes, though, what we're really interested in is a window of time about a
specific index. The operation above (looking for values in the window from 40µs
to 220µs) might be more clearly expressed as a symmetrical window about a
specific index where we know something interesting happened. To represent this,
we use the special `<|` operator:

```jl
julia> A[(-90µs .. 90µs) <| 5, :c2]
7-element AxisArrays.AxisArray{Float64,1,SubArray{Float64,1,Array{Float64,2},Tuple{UnitRange{Int64},Int64},2},Tuple{AxisArrays.Axis{:time,SIUnits.SIRange{FloatRange{Float64},Float64,0,0,1,0,0,0,0,0,0}}}}:
 -1.43958
 -0.8076
 -2.24293
  6.62473
 -4.77868
 -7.31424
 -3.14373
```

This simple concept can be extended to some very powerful behaviors. For
example, let's threshold our data and find windows about those threshold
crossings.

```jl
julia> idxs = find(diff(A[:,:c1] .< -15) .> 0)
248-element Array{Int64,1}: ...

julia> spks = A[(-200µs .. 800µs) <| idxs, :c1]
39x248 AxisArrays.AxisArray{Float64,2,Array{Float64,2},Tuple{AxisArrays.Axis{:time_sub,SIUnits.SIRange{FloatRange{Float64},Float64,0,0,1,0,0,0,0,0,0}},AxisArrays.Axis{:time_rep,Array{SIUnits.SIQuantity{Float64,0,0,1,0,0,0,0,0,0},1}}}}:
   3.76269     3.20058      6.30581   …    9.6313      9.05193     0.214391
   1.63657     3.26572      5.48104        1.4864      1.44608     6.1742
   2.18868     5.87366      1.254          0.191431    1.69441     0.998004
   3.8641      0.626106     0.147373      -1.66639    -2.91957     6.63631
  -3.89523    -2.43706      2.54553        1.7135     -2.62467    -3.57186
  -6.34036    -0.208273     2.06302   …   -5.43846    -5.53668    -6.3077
 -14.6912     -3.3506      -7.20661       -9.52052    -7.66351   -10.9802
 -26.3792    -16.0027     -20.6367       -16.4083    -17.2507    -23.289
 -31.6724    -25.7845     -19.683        -21.5722    -26.4421    -27.0657
 -40.0827    -29.7741     -29.1362       -31.2018    -33.5294    -28.8294
   ⋮                                  ⋱    ⋮
   2.65848     4.67792      2.62444        8.10507     0.972752    0.57176
  -0.735043    7.30589      2.10037   …    4.99347     7.31926    -3.97361
   1.91337    -4.53805     -3.3277         7.25753     1.24124     1.52025
   4.52168    -1.21125      0.763654      -2.29234    -2.35595    -2.28334
   1.48209    -0.79957     -6.21036        4.92486    -1.56463    -3.57588
  -3.5987      1.98851      1.0221        -4.33494     3.96454     0.522113
  -0.109871    3.17695      1.62774   …    0.998204    0.441668    6.64595
   5.56824     0.0631867    2.73849        1.53731    -4.08166     4.67527
  -1.43892    -5.00031      1.36733        3.70478    -0.25762    -1.40656
   0.76075     3.90081     -4.59973       -2.91403     0.830114   -1.92139
```

By indexing with a repeated interval, we have *added* a dimension to the
output! The returned AxisArray's columns specify each repetition of the
interval, and each datapoint in the column represents a timepoint within that
interval, adjusted by the time of the theshold crossing. We can use sparklines
to rudimentarily display the event time and waveform of the first ten
repetitions:

```jl
julia> using Sparklines
       t = axes(spks, 2)
       for i=1:10
           print(t[i], ":\t")
           sparkln(spks[:, i])
       end
0.37735 s:	▆▆▆▆▅▅▄▃▂▁▁▁▁▁▂▃▄▅▅▆▆▇▇█▇▇▇▇▆▆▅▆▆▆▅▅▆▅▆
0.79485 s:	▆▆▆▆▅▆▅▄▃▃▂▁▁▁▂▂▃▄▄▆▆▆▇▇█▇▇▇▇▆▆▅▆▆▆▆▆▅▆
0.8388 s:	▄▄▄▄▄▄▃▁▁▁▁▁▃▄▆█▆▆▄▃▃▄▃▄▃▄▃▄▄▄▄▃▄▃▄▄▄▄▃
1.05005 s:	▅▆▅▅▆▅▄▄▃▃▂▁▁▁▂▃▃▄▅▅▆▆▇▇▇▇▇█▆▆▆▅▅▆▆▆▅▅▆
1.11805 s:	▄▄▅▄▄▃▂▂▁▁▁▃▄▇█▇▆▅▄▄▄▄▄▄▄▄▄▄▄▃▃▄▄▃▃▄▄▄▄
1.245175 s:	▄▄▅▄▄▃▃▂▂▁▁▁▂▅█▇▆▆▅▄▄▄▄▃▃▄▃▄▄▄▄▃▄▃▄▃▄▄▄
1.245225 s:	▅▄▄▃▃▂▂▁▁▁▂▅█▇▆▆▅▄▄▄▄▃▃▄▃▄▄▄▄▃▄▃▄▃▄▄▄▄▄
1.534675 s:	▆▆▆▆▆▅▅▄▃▂▂▁▁▁▂▂▃▄▄▆▆▇▇▇▇█▇▇▇▆▇▆▆▆▅▆▆▆▆
1.73505 s:	▄▄▅▄▃▃▂▂▁▁▁▃▄▆█▇▆▅▄▄▄▄▅▄▄▄▄▄▄▄▄▄▄▄▃▄▄▄▄
2.3224 s:	▄▄▅▅▄▄▄▂▂▁▁▁▄▅▇▇█▆▅▄▄▄▄▄▄▄▄▄▅▅▄▅▄▄▅▅▄▄▄
```

Fancier integration with plotting packages is a WIP.

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
