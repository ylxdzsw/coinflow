# btctrade support query history trades of btc and ltc

PiggySensor = require './piggy'
pg = new PiggySensor 'btctrade'

lastid = {}
candle = {} # current candle time
trades = btc: [], ltc: [], etc: [], eth: [] # all trades after candle time

url = (x) -> "https://api.btctrade.com/api" + x

['etc', 'eth'].forEach (currency, i) ->
    pg.alignInterval 10, i, ->
        try
            batch = await pg.get url "/trades?coin=#{currency}"
        catch e
            return pg.warn e.message

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
            pg.warn "btctrade #{currency} #{candle[currency]} some data lost"
            lowest = (batch.sort (x,y) -> x.tid - y.tid)[0]
            candle[currency] = 1 + pg.candleTime lowest.date

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

['btc', 'ltc'].forEach (currency, i) ->
    pg.alignInterval 10, 2+i, ->
        if not lastid[currency]?
            lastSync = await pg.getLastSync currency

            if lastSync?
                {id, n} = JSON.parse lastSync
                candle[currency] = n + 1
                lastid[currency] = id
            else
                try
                    batch = await pg.get url "/trades?coin=#{currency}"
                catch e
                    return pg.warn e.message

                lowest = (batch.sort (x,y) -> x.tid - y.tid)[0]
                candle[currency] = 1 + pg.candleTime lowest.date
                lastid[currency] = lowest.tid

        try
            batch = await pg.get url "/trades?coin=#{currency}&since=#{lastid[currency]}"
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

parseFloat2 = (x) -> x.map (x) -> x.map (x) -> parseFloat x

['btc', 'ltc', 'etc', 'eth'].forEach (currency, i) ->
    pg.alignInterval 2, .5*i, ->
        try
            data = await pg.get url "/depth?coin=#{currency}"
        catch e
            return pg.warn e.message

        pg.saveDepth currency, parseFloat2(data.asks), parseFloat2(data.bids)
