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

AxisArrays behave like regular arrays, but they carry extra information about
their axes along with them:

```jldoctest
julia> A.time
0.0 s:2.5e-5 s:60.0 s

julia> A.chan
2-element Array{Symbol,1}:
 :c1
 :c2

```

This enables all sorts of fancy indexing behaviors. For example, we can specify
indices in *any* order, just so long as we annotate them with the axis name:

```jldoctest
julia> A[Axis{:time}(4)]
1-dimensional AxisArray{Float64,1,...} with axes:
    :chan, Symbol[:c1, :c2]
And data, a 2-element Array{Float64,1}:
 1.378246861221241
 2.756493722442482

julia> A[Axis{:chan}(:c2), Axis{:time}(1:5)]
1-dimensional AxisArray{Float64,1,...} with axes:
    :time, 0.0 s:2.5e-5 s:0.0001 s
And data, a 5-element Array{Float64,1}:
  7.141607285917661
 12.28907824673544
  6.855905417203194
  2.756493722442482
 -2.380074475771338

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
  3.427952708601597
  1.378246861221241
 -1.190037237885669
 -1.994137635575063
  2.9429034802756004
 -0.22644919919326786
  0.8214461136364685

julia> AxisArrays.axes(ans, 1)
Axis{:time,StepRangeLen{Unitful.Quantity{Float64,𝐓,Unitful.FreeUnits{(s,),𝐓,nothing}},Base.TwicePrecision{Unitful.Quantity{Float64,𝐓,Unitful.FreeUnits{(s,),𝐓,nothing}}},Base.TwicePrecision{Unitful.Quantity{Float64,𝐓,Unitful.FreeUnits{(s,),𝐓,nothing}}}}}(5.0e-5 s:2.5e-5 s:0.0002 s)

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
 6.14453912336772

```

You can even index by multiple values by broadcasting `atvalue` over an array:

```jldoctest
julia> A[atvalue.([2.5e-5s, 75.0µs])]
2-dimensional AxisArray{Float64,2,...} with axes:
    :time, Unitful.Quantity{Float64,𝐓,Unitful.FreeUnits{(s,),𝐓,nothing}}[2.5e-5 s, 7.5e-5 s]
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
 12.28907824673544
  6.855905417203194
  2.756493722442482
 -2.380074475771338
 -3.988275271150126
  5.885806960551201
 -0.4528983983865357

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
    :time_rep, Unitful.Quantity{Float64,𝐓,Unitful.FreeUnits{(s,),𝐓,nothing}}[0.161275 s, 0.489925 s, 0.957175 s, 1.1457 s, 1.40185 s, 1.84193 s, 2.07365 s, 2.32947 s, 2.7763 s, 2.79275 s  …  57.6724 s, 57.7152 s, 57.749 s, 58.1109 s, 58.3783 s, 58.4178 s, 58.921 s, 59.1693 s, 59.6546 s, 59.7824 s]
And data, a 41×273 Array{Float64,2}:
  -2.47171    -1.72242     4.54491     …    2.74969     3.1869     -2.00435
   6.78576     3.65903     5.14183         -0.98535     3.96603    -5.74065
   1.56584     1.88131     0.470257         2.66664     5.27674     0.0610194
   4.78242     3.20142     3.28502          5.20484    -3.66085     1.16247
   3.23148    -1.24878    -0.0252124        5.46585     4.88651     3.64283
   6.5714      0.572557    3.038       …   -0.974689    2.61297     7.3496
   4.46643    -0.444754   -4.52857          0.304449   -1.54659    -2.53197
  -9.57806    -1.29114    -2.23969         -9.10793    -6.35711    -5.06038
 -12.2567     -5.06283    -8.53581        -11.9826    -14.868     -14.0543
 -24.5458    -19.9823    -20.0798         -20.3065    -18.5437    -25.3609
   ⋮                                   ⋱    ⋮
   2.14059    -0.365031    1.36771         -4.23763     5.9211     -3.84708
   3.58157     2.87076     0.835568        -2.27752     1.18686     2.3412
   6.7953     -1.32384    -3.0897           0.464151   -1.12327    -2.14844
   1.19649     2.44709    -5.16029     …   -0.965397    2.37465    -2.36185
  -1.57253     0.526027    0.831144         0.6505      3.61602     1.93462
   0.739684   -1.74925    -6.18072         -7.36229    -0.187708    1.97774
   0.645211    1.04006    -1.33676          4.30262    -4.46544    -0.278097
   1.32901    -1.74821     1.94781          0.780325    3.22951    -0.436806
   0.387814    0.128453   -0.00287742  …   -1.51196    -2.10081    -2.26663

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
