using FactCheck, MarketData

facts("conversion from TimeArray to AxisArray") do

    context("axes values are correct") do
        @fact AxisArray(AAPL).axes[1][1] => Date(1980,12,12)
        @fact AxisArray(AAPL).axes[2][1] => "Open"
        @fact_throws AxisArray(cl).axes[2]
    end

    context("data values are correct") do
        @fact AxisArray(AAPL).data[1]    => 28.75
        @fact AxisArray(AAPL).data[8336] => 554.17
    end
end

facts("moving") do

    context("moving only works on single column") do
        @fact moving(AxisArray(cl), mean, 10)[1] => roughly(98.782)
        @fact_throws moving(AxisArray(AAPL), mean, 10) 
    end
end

facts("merge") do

    context("only inner join supported") do
        @fact size(merge(AxisArray(AAPL), AxisArray(BA)),1) => 8335
    end
end
