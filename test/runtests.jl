using AxisArrays
using Dates
using Test
using Random
import IterTools

@testset "AxisArrays" begin
    @test length(detect_ambiguities(AxisArrays, Base, Core)) <= 1
    # With IntervalSets 0.4, one ambiguity:
    # getindex(A::AxisArray, idxs...) vs getindex(A::AbstractArray, ::EllipsisNotation.Ellipsis)

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
