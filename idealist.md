1. ignore trades that have too small amount
2. saveCandle asynchronizely
3. check local time and server time in every API that return timestamp
4. ensure depth info not overide by old but slow (> 2sec) request
5. 比较各交易所深度信息，第一和最后出价价差，价格平均量，最小价差，深度信息内总量等
