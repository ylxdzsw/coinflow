1. ignore trades that have too small amount
2. saveCandle asynchronizely
3. check local time and server time in every API that return timestamp
4. ensure depth info not overide by old but slow (> 2sec) request
