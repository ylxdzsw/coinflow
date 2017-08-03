PiggySensor = require './piggy'
pg = new PiggySensor 'okcoin'

ids    = btc: [], ltc: [], eth: []
trades = btc: [], ltc: [], eth: []

url = (x) -> "https://www.okcoin.cn/api/v1" + x

['btc', 'ltc', 'eth'].forEach (currency, i) ->
    pg.alignInterval 5, i, ->
        for trade in await pg.get url "/trades.do?symbol=#{currency}_cny"
            if trade.tid not in ids[currency]
                ids[currency].push trade.tid
                trades[currency].push
                    price: parseFloat(trade.price)
                    amount: parseFloat(trade.amount)

['btc', 'ltc', 'eth'].forEach (currency, i) ->
    pg.alignInterval 2, .5*i, ->
        data = await pg.get url "/depth.do?symbol=#{currency}_cny&size=50"
        pg.saveDepth data.asks, data.bids, currency

pg.alignInterval 300, 0, (n) ->
    for currency in ['btc', 'ltc', 'eth']
        candle = pg.createCandle trades[currency], n
        continue if not candle?

        pg.saveCandle candle, currency
        trades[currency] = []
        ids[currency] = ids[currency][-1024..]
