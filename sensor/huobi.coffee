PiggySensor = require './piggy'
pg = new PiggySensor 'huobi'

ids    = btc: [], ltc: [], etc: [], eth: []
trades = btc: [], ltc: [], etc: [], eth: []

# == new api (for etc and eth) == #

newurl = (x) -> "https://be.huobi.com" + x

['etc', 'eth'].forEach (currency, i) ->
    pg.alignInterval 5, i+3, ->
        data = await pg.get newurl "/market/trade?symbol=#{currency}cny"
        return pg.warn "Huobi responses error #{JSON.strinify data}" if data.status is 'error'
        for trade in data.tick.data
            if trade.id not in ids[currency]
                ids[currency].push trade.id
                trades[currency].push trade

['etc', 'eth'].forEach (currency, i) ->
    pg.alignInterval 2, i, ->
        data = await pg.get newurl "/market/depth?symbol=#{currency}cny&type=step1"
        return pg.warn "Huobi responses error #{JSON.strinify data}" if data.status is 'error'
        pg.saveDepth data.tick.asks, data.tick.bids, currency

# == old api (for btc and ltc) == #

oldurl = (x) -> "http://api.huobi.com/staticmarket/detail_#{x}_json.js"

parseDepth = ({price, amount}) -> [price, amount]

['btc', 'ltc'].forEach (currency, i) ->
    pg.alignInterval 2, i+.5, ->
        data = await pg.get oldurl currency
        for trade in data.trades
            if trade.id not in ids[currency]
                ids[currency].push trade.id
                trades[currency].push trade
        pg.saveDepth data.sells.map(parseDepth), data.buys.map(parseDepth), currency

# == common logic == #

pg.alignInterval 300, 0, (n) ->
    for currency in ['btc', 'ltc', 'etc', 'eth']
        candle = pg.createCandle trades[currency], n
        continue if not candle?

        pg.saveCandle candle, currency
        trades[currency] = []
        ids[currency] = ids[currency][-1024..]
