# NamedAxesArrays

[![Build Status](https://travis-ci.org/timholy/NamedAxesArrays.jl.svg?branch=master)](https://travis-ci.org/timholy/NamedAxesArrays.jl)

This package (not yet functional) for the Julia language will allow you to index arrays using names for the individual axes.
This permits one to implement algorithms that are oblivious to the storage order of the underlying arrays.
In contrast to similar approaches in [Images.jl](https://github.com/timholy/Images.jl) and [NamedArrays.jl](https://github.com/davidavdav/NamedArrays),
this should enable implementation of all basic operations without introducing any runtime overhead.

A brief demo of some of the intended functionality:
```julia
A = rand(3, 5, 10)
B = NamedAxesArray(A, (:x, :y, :z))
Bslice = B[Ax{:y}(3)]  # equivalent to `slice(B, :, 3, :)`

# Compute the intensity-weighted mean along the z axis
Itotal = sumz = 0.0
for iter in eachelement(B)  # traverses in storage order for cache efficiency
    I = B[iter]  # intensity in a single voxel
    Itotal += I
    sumz += I * iter.z  # iter.z "looks up" the current z position
end
meanz = sumz/Itotal
```

The intention is that all of these operations are just as efficient as they would be if you used traditional position-based indexing with all the inherent assumptions about the storage order of `B`.
