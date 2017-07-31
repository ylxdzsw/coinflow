PiggySensor = require './piggy'
pg = new PiggySensor 'chbtc'

ids    = btc: [], ltc: [], etc: [], eth: []
trades = btc: [], ltc: [], etc: [], eth: []

url = (x) -> "http://api.chbtc.com/data/v1" + x

pg.alignInterval 2, (n) ->
    data = await pg.get url '/trades?currency=btc_cny'
    console.log n
    true

onTrade = (data) ->
    currency = data.channel[..2]
    for trade in data.data
        if trade.tid not in ids[currency]
            ids[currency].push trade.tid
            trades[currency].push trade

pg.alignInterval 300, (n) ->
    for currency in ['btc', 'ltc', 'etc', 'eth']
        candle = pg.createCandle trades[currency], n
        pg.saveCandle candle, currency
