PiggySensor = require './piggy'
pg = new PiggySensor 'jubi'

ids    = btc: [], ltc: [], etc: [], eth: []
trades = btc: [], ltc: [], etc: [], eth: []

url = (x) -> "https://www.jubi.com/api/v1" + x

pg.alignInterval 10, ->
    updateTrades currency for currency in ['btc', 'ltc', 'etc', 'eth']

updateTrades = (currency) ->
    for trade in await pg.get url "/orders?coin=#{currency}"
        if trade.tid not in ids[currency]
            ids[currency].push trade.tid
            trades[currency].push trade

pg.alignInterval 2, ->
    updateDepth currency for currency in ['btc', 'ltc', 'etc', 'eth']

updateDepth = (currency) ->
    data = await pg.get url "/depth?coin=#{currency}"
    pg.saveDepth data.asks, data.bids, currency

pg.alignInterval 300, (n) ->
    for currency in ['btc', 'ltc', 'etc', 'eth']
        candle = pg.createCandle trades[currency], n
        continue if not candle?

        pg.saveCandle candle, currency
        trades[currency] = []
        ids[currency] = ids[currency][-1024..]
