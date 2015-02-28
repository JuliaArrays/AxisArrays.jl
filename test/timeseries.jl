using AxisArrays.TimeArray, MarketData

facts("Apple and Boeing AxisArrays") do

    context("Apple and Boeing have correct axes values") do
        @fact Apple.axes[1][1]  => Date(1980,12,12) 
        @fact Apple.axes[2][1]  => "Open"
        @fact Boeing.axes[1][1] => Date(1962,1,2) 
        @fact Boeing.axes[2][1] => "Open"
    end 
    context("Apple and Boeing have correct data values") do
        @fact Apple.data[1][1]  => 28.75
        @fact size(Apple,1)     => 8336
        @fact size(Apple,2)     => 12
        @fact Boeing.data[1][1] => 50.88
        @fact size(Boeing,1)    => 13090
        @fact size(Boeing,2)    => 12
    end
end
