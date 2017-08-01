PiggySensor = require './piggy'
pg = new PiggySensor 'huobi'

ids    = btc: [], ltc: [], etc: [], eth: []
trades = btc: [], ltc: [], etc: [], eth: []

# == new api (for etc and eth) == #

url = (x) -> "https://be.huobi.com" + x

pg.alignInterval 5, ->
    updateTrades currency for currency in ['etc', 'eth']

updateTrades = (currency) ->
    data = await pg.get url "/market/trade?symbol=#{currency}cny"
    return pg.warn "Huobi responses error #{JSON.strinify data}" if data.status is 'error'
    for trade in data.tick.data
        if trade.id not in ids[currency]
            ids[currency].push trade.id
            trades[currency].push trade

pg.alignInterval 2, ->
    updateDepth currency for currency in ['etc', 'eth']

updateDepth = (currency) ->
    data = await pg.get url "/market/depth?symbol=#{currency}cny&type=step1"
    return pg.warn "Huobi responses error #{JSON.strinify data}" if data.status is 'error'
    pg.saveDepth data.tick.asks, data.tick.bids, currency

# == old api (for btc and ltc) == #

oldurl = (x) -> "http://api.huobi.com/staticmarket/detail_#{x}_json.js"

pg.alignInterval 2, ->
    oldupdate currency for currency in ['btc', 'ltc']

oldupdate = (currency) ->
    data = await pg.get oldurl currency
    for trade in data.trades
        if trade.id not in ids[currency]
            ids[currency].push trade.id
            trades[currency].push trade
    pg.saveDepth data.sells, data.buys, currency

# == common logic == #

pg.alignInterval 300, (n) ->
    for currency in ['btc', 'ltc', 'etc', 'eth']
        candle = pg.createCandle trades[currency], n
        continue if not candle?

        pg.saveCandle candle, currency
        trades[currency] = []
        ids[currency] = ids[currency][-1024..]
