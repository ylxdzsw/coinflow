PiggySensor = require './piggy'
pg = new PiggySensor 'chbtc'

lastid = {}
candle = {} # current candle time
trades = btc: [], ltc: [], etc: [], eth: [] # all trades after candle time

url = (x) -> "http://api.chbtc.com/data/v1" + x

['btc', 'ltc', 'etc', 'eth'].forEach (currency, i) ->
    pg.alignInterval 5, i, ->
        batch = await pg.get url "/trades?currency=#{currency}_cny"

        if not lastid[currency]?
            lowest = (batch.sort (x,y) -> x.tid - y.tid)[0]
            lastSync = await pg.getLastSync currency

            if lastSync?
                {id, n} = JSON.parse lastSync

                if lowest.tid <= id + 1
                    candle[currency] = n + 1
                    lastid[currency] = id

            if not lastid[currency]?
                n = pg.candleTime lowest.date
                candle[currency] = n + 1
                lastid[currency] = (x.tid for x in batch when pg.candleTime(x.date) is n).sort().pop()

        if (batch.some (x) -> x.tid <= lastid[currency])
            batch = batch.filter (x) -> x.tid > lastid[currency]
            return if batch.length is 0
        else
            pg.warn "chbtc #{currency} #{candle[currency]} some data lost"
            candle[currency] += 1

        trades[currency] = trades[currency].concat batch
        lastid[currency] = (x.tid for x in batch).sort().pop()

        period = pg.secondTime candle[currency] + 1

        if (batch.some (x) -> x.date >= period)
            candleTrades = trades[currency].filter (x) -> pg.candleTime(x.date) is candle[currency]

            if candleTrades.length > 0
                latest = (x.tid for x in candleTrades).sort().pop()
                pg.saveCandle currency, pg.createCandle candleTrades, candle[currency]
                pg.setLastSync currency, id: latest, n: candle[currency]

            trades[currency] = trades[currency].filter (x) -> x.date >= period
            candle[currency] += 1

['btc', 'ltc', 'etc', 'eth'].forEach (currency, i) ->
    pg.alignInterval 2, .5*i, ->
        data = await pg.get url "/depth?currency=#{currency}_cny&size=50"
        pg.saveDepth currency, data.asks, data.bids
