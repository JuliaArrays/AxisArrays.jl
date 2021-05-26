if isdefined(OffsetArrays, :centered)
    # only test this if we're using OffsetArrays at least v1.9
    @testset "centered" begin
        check_range(r, f, l) = (@test first(r) == f; @test last(r) == l)
        check_range_axes(r, f, l) = check_range(Base.axes(r)[1], f, l)

        check_range(Base.axes(OffsetArrays.centered(1:3))[1], -1, 1)
        a = AxisArray(rand(3, 3), Axis{:y}(0.1:0.1:0.3), Axis{:x}(1:3))

        ca = OffsetArrays.centered(a)
        axs = Base.axes(ca)
        check_range(axs[1], -1, 1)
        check_range(axs[2], -1, 1)
        @test ca[OffsetArrays.center(ca)...] == a[OffsetArrays.center(a)...]

        axs = AxisArrays.axes(ca)
        check_range(axs[1].val, 0.1, 0.3)
        check_range(axs[2].val, 1, 3)
        check_range_axes(axs[1].val, -1, 1)
        check_range_axes(axs[1].val, -1, 1)
    end
end
