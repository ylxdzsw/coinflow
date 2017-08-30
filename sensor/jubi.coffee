# jubi didn't describe `since` parameter in their document
# but it support it and can query history of all coins

PiggySensor = require './piggy'
pg = new PiggySensor 'jubi'

lastid = {}
candle = {} # current candle time
trades = btc: [], ltc: [], etc: [], eth: [] # all trades after candle time

url = (x) -> "https://www.jubi.com/api/v1" + x

['btc', 'ltc', 'etc', 'eth'].forEach (currency, i) ->
    pg.alignInterval 10, i, ->
        if not lastid[currency]?
            lastSync = await pg.getLastSync currency

            if lastSync?
                {id, n} = JSON.parse lastSync
                candle[currency] = n + 1
                lastid[currency] = id
            else
                try
                    batch = await pg.get url "/orders?coin=#{currency}"
                catch e
                    return pg.warn e.message

                lowest = (batch.sort (x,y) -> x.tid - y.tid)[0]
                candle[currency] = 1 + pg.candleTime lowest.date
                lastid[currency] = lowest.tid

        try
            batch = await pg.get url "/orders?coin=#{currency}&since=#{lastid[currency]}"
        catch e
            return pg.warn e.message

        return if batch.length is 0

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
        try
            data = await pg.get url "/depth?coin=#{currency}"
        catch e
            pg.warn e.message if not e.message.includes 204 # ignore 204 which indicates no update
            return

        pg.saveDepth currency, data.asks, data.bids
