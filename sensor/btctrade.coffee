PiggySensor = require './piggy'
pg = new PiggySensor 'btctrade'

ids    = btc: [], ltc: [], etc: [], eth: []
trades = btc: [], ltc: [], etc: [], eth: []

url = (x) -> "https://api.btctrade.com/api" + x

pg.alignInterval 5, ->
    updateTrades currency for currency in ['btc', 'ltc', 'etc', 'eth']

updateTrades = (currency) ->
    for trade in await pg.get url "/trades?coin=#{currency}"
        if trade.tid not in ids[currency]
            ids[currency].push trade.tid
            trades[currency].push trade

pg.alignInterval 2, ->
    updateDepth currency for currency in ['btc', 'ltc', 'etc', 'eth']

parseFloat2 = (x) -> x.map (x) -> x.map (x) -> parseFloat x

updateDepth = (currency) ->
    data = await pg.get url "/depth?coin=#{currency}"
    pg.saveDepth parseFloat2(data.asks), parseFloat2(data.bids), currency

pg.alignInterval 300, (n) ->
    for currency in ['btc', 'ltc', 'etc', 'eth']
        candle = pg.createCandle trades[currency], n
        continue if not candle?

        pg.saveCandle candle, currency
        trades[currency] = []
        ids[currency] = ids[currency][-1024..]
