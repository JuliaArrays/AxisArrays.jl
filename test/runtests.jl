using AxisArrays
using Base.Test
import IterTools

@testset "AxisArrays" begin
    # during this time there was an ambiguity in base with checkbounds_linear_indices
    if VERSION < v"0.6.0-dev.2374" || VERSION >= v"0.6.0-dev.2884"
        @test isempty(detect_ambiguities(AxisArrays, Base, Core))
    end

    @testset "Core" begin
        include("core.jl")
    end

    @testset "Intervals" begin
        include("intervals.jl")
    end

    @testset "Indexing" begin
        include("indexing.jl")
    end

    @testset "SortedVector" begin
        include("sortedvector.jl")
    end

    @testset "CategoricalVector" begin
        include("categoricalvector.jl")
    end

    @testset "Search" begin
        include("search.jl")
    end

    @testset "Combine" begin
        include("combine.jl")
    end

    @testset "README" begin
        include("readme.jl")
    end
end
