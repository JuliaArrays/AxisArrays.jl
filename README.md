# AxisArrays

[![Build Status](https://travis-ci.org/mbauman/AxisArrays.jl.svg?branch=master)](https://travis-ci.org/mbauman/AxisArrays.jl)

This package (not yet functional) for the Julia language will allow you to index arrays using names for the individual axes and keep track of dimensional axes.
This permits one to implement algorithms that are oblivious to the storage order of the underlying arrays.
In contrast to similar approaches in [Images.jl](https://github.com/timholy/Images.jl) and [NamedArrays.jl](https://github.com/davidavdav/NamedArrays),
this should enable implementation of all basic operations without introducing any runtime overhead.

See https://github.com/mbauman/Signals.jl/issues/12 for a design sketch.
