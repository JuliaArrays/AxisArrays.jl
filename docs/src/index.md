```@meta
DocTestSetup = quote
    using AxisArrays, Unitful
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

[![Build Status](https://travis-ci.org/JuliaArrays/AxisArrays.jl.svg?branch=master)](https://travis-ci.org/JuliaArrays/AxisArrays.jl) [![Coverage Status](https://coveralls.io/repos/github/JuliaArrays/AxisArrays.jl/badge.svg?branch=master)](https://coveralls.io/github/JuliaArrays/AxisArrays.jl?branch=master)

This package for the Julia language provides an array type (the `AxisArray`) that knows about its dimension names and axis values.
This allows for indexing with the axis name without incurring any runtime overhead.
AxisArrays can also be indexed by the values of their axes, allowing column names or interval selections.
This permits one to implement algorithms that are oblivious to the storage order of the underlying arrays.
In contrast to similar approaches in [Images.jl](https://github.com/timholy/Images.jl) and [NamedArrays.jl](https://github.com/davidavdav/NamedArrays), this allows for type-stable selection of dimensions and compile-time axis lookup.  It is also better suited for regularly sampled axes, like samples over time.

Collaboration is welcome! This is still a work-in-progress. See [the roadmap](https://github.com/JuliaArrays/AxisArrays.jl/issues/7) for the project's current direction.

## Example of currently-implemented behavior:

```julia
julia> Pkg.add("AxisArrays")
julia> using AxisArrays, Unitful
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
    :time, 0.0 s:2.5e-5 s:60.0 s
    :chan, Symbol[:c1, :c2]
And data, a 2400001×2 Array{Float64,2}:
  3.5708     7.14161
  6.14454   12.2891
  3.42795    6.85591
  1.37825    2.75649
 -1.19004   -2.38007
 -1.99414   -3.98828
  2.9429     5.88581
 -0.226449  -0.452898
  0.821446   1.64289
 -0.582687  -1.16537
  ⋮
 -3.50593   -7.01187
  2.26783    4.53565
 -0.16902   -0.33804
 -3.84852   -7.69703
  0.226457   0.452914
  0.560809   1.12162
  4.67663    9.35326
 -2.41005   -4.8201
 -3.71612   -7.43224

```

AxisArrays behave like regular arrays, but they additionally use the axis
information to enable all sorts of fancy behaviors. For example, we can specify
indices in *any* order, just so long as we annotate them with the axis name:

```jldoctest
julia> A[Axis{:time}(4)]
1-dimensional AxisArray{Float64,1,...} with axes:
    :chan, Symbol[:c1, :c2]
And data, a 2-element Array{Float64,1}:
 1.37825
 2.75649

julia> A[Axis{:chan}(:c2), Axis{:time}(1:5)]
1-dimensional AxisArray{Float64,1,...} with axes:
    :time, 0.0 s:2.5e-5 s:0.0001 s
And data, a 5-element Array{Float64,1}:
  7.14161
 12.2891
  6.85591
  2.75649
 -2.38007

```

We can also index by the *values* of each axis using an `Interval` type that
selects all values between two endpoints `a .. b` or the axis values directly.
Notice that the returned AxisArray still has axis information itself... and it
still has the correct time information for those datapoints!

```jldoctest
julia> A[40µs .. 220µs, :c1]
1-dimensional AxisArray{Float64,1,...} with axes:
    :time, 5.0e-5 s:2.5e-5 s:0.0002 s
And data, a 7-element Array{Float64,1}:
  3.42795
  1.37825
 -1.19004
 -1.99414
  2.9429
 -0.226449
  0.821446

julia> AxisArrays.axes(ans, 1)
AxisArrays.Axis{:time,StepRangeLen{Quantity{Float64, Dimensions:{𝐓}, Units:{s}},Base.TwicePrecision{Quantity{Float64, Dimensions:{𝐓}, Units:{s}}},Base.TwicePrecision{Quantity{Float64, Dimensions:{𝐓}, Units:{s}}}}}(5.0e-5 s:2.5e-5 s:0.0002 s)

```

You can also index by a single value on an axis using `atvalue`. This will drop
a dimension. Indexing with an `Interval` type retains dimensions, even
when the ends of the interval are equal:

```jldoctest
julia> A[atvalue(2.5e-5s), :c1]
6.14453912336772

julia> A[2.5e-5s..2.5e-5s, :c1]
1-dimensional AxisArray{Float64,1,...} with axes:
    :time, 2.5e-5 s:2.5e-5 s:2.5e-5 s
And data, a 1-element Array{Float64,1}:
 6.14454

```

You can even index by multiple values by broadcasting `atvalue` over an array:

```jldoctest
julia> A[atvalue.([2.5e-5s, 75.0µs])]
2-dimensional AxisArray{Float64,2,...} with axes:
    :time, Quantity{Float64, Dimensions:{𝐓}, Units:{s}}[2.5e-5 s, 7.5e-5 s]
    :chan, Symbol[:c1, :c2]
And data, a 2×2 Array{Float64,2}:
 6.14454  12.2891
 1.37825   2.75649

```

Sometimes, though, what we're really interested in is a window of time about a
specific index. One of the operations above (looking for values in the window from 40µs
to 220µs) might be more clearly expressed as a symmetrical window about a
specific index where we know something interesting happened. To represent this,
we use the `atindex` function:

```jldoctest
julia> A[atindex(-90µs .. 90µs, 5), :c2]
1-dimensional AxisArray{Float64,1,...} with axes:
    :time_sub, -7.5e-5 s:2.5e-5 s:7.5e-5 s
And data, a 7-element Array{Float64,1}:
 12.2891
  6.85591
  2.75649
 -2.38007
 -3.98828
  5.88581
 -0.452898

```

Note that the returned AxisArray has its time axis shifted to represent the
interval about the given index!  This simple concept can be extended to some
very powerful behaviors. For example, let's threshold our data and find windows
about those threshold crossings.

```jldoctest
julia> idxs = findall(diff(A[:,:c1] .< -15) .> 0);

julia> spks = A[atindex(-200µs .. 800µs, idxs), :c1]
2-dimensional AxisArray{Float64,2,...} with axes:
    :time_sub, -0.0002 s:2.5e-5 s:0.0008 s
    :time_rep, Quantity{Float64, Dimensions:{𝐓}, Units:{s}}[0.162 s, 0.20045 s, 0.28495 s, 0.530325 s, 0.821725 s, 1.0453 s, 1.11967 s, 1.1523 s, 1.22085 s, 1.6253 s  …  57.0094 s, 57.5818 s, 57.8716 s, 57.8806 s, 58.4353 s, 58.7041 s, 59.1015 s, 59.1783 s, 59.425 s, 59.5657 s]
And data, a 41×247 Array{Float64,2}:
  -1.82238     2.3315      -1.56147   …    4.33751     4.77713    -1.81713
   0.672063    7.25649      0.633375       1.54583     5.81194    -4.706
  -1.65182     2.57487      0.477408       3.09505     3.52478     4.13037
   4.46035     2.11313      4.78372        1.23385     7.2525      3.57485
   5.25651    -2.19785      3.05933        0.965021    6.78414     5.94854
   7.8537      0.345008     0.960533  …    0.812989    0.336715    0.303909
   0.466816    0.643649    -3.67087        3.92978    -3.1242      0.789722
  -6.0445    -13.2441      -4.60716        0.265144   -4.50987    -8.84897
  -9.21703   -13.2254     -14.4409        -8.6664    -13.3457    -11.6213
 -16.1809    -22.7037     -25.023        -15.9376    -28.0817    -16.996
   ⋮                                  ⋱                ⋮
   1.72728     4.77428    -10.3922        -2.08555     1.19198    -1.94365
  -0.301629    0.0683982   -4.36574        1.92362    -5.12333    -3.4431
   4.7182      1.18615      4.40717       -4.51757    -8.64314     0.0800021
  -2.43775    -0.151882    -1.40817   …   -3.38555    -2.23418     0.728549
   3.2482     -0.60967      0.471288       2.53395     0.468817   -3.65905
  -4.26967     2.24747     -3.13758        1.74967     4.5052     -0.145357
  -0.752487    1.69446     -1.20491        1.71429     1.81936     0.290158
   4.64348    -3.94187     -1.59213        7.15428    -0.539748    4.82309
   1.09652    -2.66999      0.521931  …   -3.80528     1.70421     3.40583

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
