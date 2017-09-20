# AxisArrays

[![0.6 Pkg Status](http://pkg.julialang.org/badges/AxisArrays_0.6.svg)](http://pkg.julialang.org/?pkg=AxisArrays)

[![Build Status](https://travis-ci.org/JuliaArrays/AxisArrays.jl.svg?branch=master)](https://travis-ci.org/JuliaArrays/AxisArrays.jl)
[![Coverage Status](https://coveralls.io/repos/github/JuliaArrays/AxisArrays.jl/badge.svg?branch=master)](https://coveralls.io/github/JuliaArrays/AxisArrays.jl?branch=master)
[![Stable Documentation][docs-stable-img]][docs-stable-url]
[![Latest Documentation][docs-latest-img]][docs-latest-url]

This package for the Julia language provides an array type (the `AxisArray`) that knows about its dimension names and axis values.
This allows for indexing with the axis name without incurring any runtime overhead.
AxisArrays can also be indexed by the values of their axes, allowing column names or interval selections.
This permits one to implement algorithms that are oblivious to the storage order of the underlying arrays.
In contrast to similar approaches in [NamedArrays.jl](https://github.com/davidavdav/NamedArrays) and old versions of [Images.jl](https://github.com/timholy/Images.jl), this allows for type-stable selection of dimensions and compile-time axis lookup.  It is also better suited for regularly sampled axes, like samples over time.

Collaboration is welcome! This is still a work-in-progress. See [the roadmap](https://github.com/JuliaArrays/AxisArrays.jl/issues/7) for the project's current direction.

**Installation**: at the Julia REPL, `Pkg.add("AxisArrays")`

**Documentation**: [![Stable Documentation][docs-stable-img]][docs-stable-url] [![Latest Documentation][docs-latest-img]][docs-latest-url]

[docs-latest-img]: https://img.shields.io/badge/docs-latest-blue.svg
[docs-latest-url]: http://juliaarrays.github.io/AxisArrays.jl/latest/

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: http://juliaarrays.github.io/AxisArrays.jl/stable/
