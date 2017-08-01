PiggySensor = require './piggy'
pg = new PiggySensor 'okcoin'

ids    = btc: [], ltc: [], eth: []
trades = btc: [], ltc: [], eth: []

url = (x) -> "https://www.okcoin.cn/api/v1" + x

pg.alignInterval 5, ->
    updateTrades currency for currency in ['btc', 'ltc', 'eth']

updateTrades = (currency) ->
    for trade in await pg.get url "/trades.do?symbol=#{currency}_cny"
        if trade.tid not in ids[currency]
            ids[currency].push trade.tid
            trades[currency].push
                price: parseFloat(trade.price)
                amount: parseFloat(trade.amount)

pg.alignInterval 2, ->
    updateDepth currency for currency in ['btc', 'ltc', 'eth']

updateDepth = (currency) ->
    data = await pg.get url "/depth.do?symbol=#{currency}_cny&size=50"
    pg.saveDepth data.asks, data.bids, currency

pg.alignInterval 300, (n) ->
    for currency in ['btc', 'ltc', 'eth']
        candle = pg.createCandle trades[currency], n
        continue if not candle?

        pg.saveCandle candle, currency
        trades[currency] = []
        ids[currency] = ids[currency][-1024..]
