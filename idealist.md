1. ignore trades that have too small amount
2. saveCandle asynchronizely
3. check local time and server time in every API that return timestamp
4. ensure depth info not overide by old but slow (> 2sec) request
5. 比较各交易所深度信息，第一和最后出价价差，价格平均量，最小价差，深度信息内总量等
6. check sensor pid to ensure not duplicate
7. add timeout for huobi APIs: sometimes it will loss all data silently
8. findout why okcoin ltc often loss data (maybe just because it is too active)
9. slowdown when not active
10. buy more coin so we get the right number after paying fees
