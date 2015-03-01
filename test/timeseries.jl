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
