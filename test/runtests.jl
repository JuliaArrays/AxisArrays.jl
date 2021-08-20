using AxisArrays
using Dates
using Test
using Random
using OffsetArrays
import IterTools

@testset "AxisArrays" begin
    VERSION >= v"1.1" && @test isempty(detect_ambiguities(AxisArrays, Base, Core))

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

    @testset "OffsetArrays" begin
        include("offsetarrays.jl")
    end
end
