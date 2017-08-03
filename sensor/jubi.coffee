PiggySensor = require './piggy'
pg = new PiggySensor 'jubi'

ids    = btc: [], ltc: [], etc: [], eth: []
trades = btc: [], ltc: [], etc: [], eth: []

url = (x) -> "https://www.jubi.com/api/v1" + x

['btc', 'ltc', 'etc', 'eth'].forEach (currency, i) ->
    pg.alignInterval 5, i, ->
        for trade in await pg.get url "/orders?coin=#{currency}"
            if trade.tid not in ids[currency]
                ids[currency].push trade.tid
                trades[currency].push trade

['btc', 'ltc', 'etc', 'eth'].forEach (currency, i) ->
    pg.alignInterval 2, .5*i, ->
        try
            data = await pg.get url "/depth?coin=#{currency}"
        catch e
            if e.message.includes 204 # ignore 204 which indicates no update
                return
            else
                throw e
        pg.saveDepth data.asks, data.bids, currency

pg.alignInterval 300, 0, (n) ->
    for currency in ['btc', 'ltc', 'etc', 'eth']
        candle = pg.createCandle trades[currency], n
        continue if not candle?

        pg.saveCandle candle, currency
        trades[currency] = []
        ids[currency] = ids[currency][-1024..]
