using AxisArrays, MarketData

module TimeArray

using AxisArrays, MarketData

export Apple, Boeing 

const Apple  = AxisArray(AAPL.values, (AAPL.timestamp, AAPL.colnames))
const Boeing = AxisArray(BA.values, (BA.timestamp, BA.colnames))
 
end
