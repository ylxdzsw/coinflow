PiggySensor = require './piggy'
pg = new PiggySensor 'btctrade'

ids    = btc: [], ltc: [], etc: [], eth: []
trades = btc: [], ltc: [], etc: [], eth: []

url = (x) -> "https://api.btctrade.com/api" + x

['btc', 'ltc', 'etc', 'eth'].forEach (currency, i) ->
    pg.alignInterval 5, i, ->
        for trade in await pg.get url "/trades?coin=#{currency}"
            if trade.tid not in ids[currency]
                ids[currency].push trade.tid
                trades[currency].push trade

parseFloat2 = (x) -> x.map (x) -> x.map (x) -> parseFloat x

['btc', 'ltc', 'etc', 'eth'].forEach (currency, i) ->
    pg.alignInterval 2, .5*i, ->
        data = await pg.get url "/depth?coin=#{currency}"
        pg.saveDepth parseFloat2(data.asks), parseFloat2(data.bids), currency

pg.alignInterval 300, 0, (n) ->
    for currency in ['btc', 'ltc', 'etc', 'eth']
        candle = pg.createCandle trades[currency], n
        continue if not candle?

        pg.saveCandle candle, currency
        trades[currency] = []
        ids[currency] = ids[currency][-1024..]
