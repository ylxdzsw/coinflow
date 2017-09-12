PiggySensor = require './piggy'
WebSocket   = require 'ws'

util = require 'util'
zlib = require 'zlib'

pg = new PiggySensor 'huobi'

unzip = util.promisify zlib.unzip
sleep = util.promisify setTimeout

lastid = {}
candle = {} # current candle time
trades = btc: [], ltc: [], etc: [], eth: [] # all trades after candle time

getid = do (c=0) -> () -> 'id'+c++

ws =
    wsnew: null
    wsold: null
    ch: {}

    register: (f) ->
        id = do getid
        do =>
            await sleep 5000
            if @ch[id]?
                pg.warn "task #{id} timeout after 5s"
                delete @ch[id]
        @ch[id] = (args...) =>
            delete @ch[id]
            f(args...)
        id

    init_new: () ->
        sock = new WebSocket('wss://be.huobi.com/ws')
            .on 'message', (data) =>
                data = JSON.parse await unzip data

                switch
                    when 'ping' of data
                        sock.send JSON.stringify pong: data.ping
                    when 'id' of data
                        @ch[data.id]? data
                    when 'ch' of data
                        @ch[data.ch] data.tick
                    else
                        pg.warn "server send unknown message #{data}"

            .on 'open', () =>
                pg.info "web socket connected: be.huobi.com"
                @wsnew = sock
                ['etc', 'eth'].forEach (currency) =>
                    id = @register ({status}) -> pg.warn "subscription failed" if status is 'error'
                    sock.send JSON.stringify sub: "market.#{currency}cny.depth.step0", id: id
                    @ch["market.#{currency}cny.depth.step0"] = (data) ->
                        pg.saveDepth currency, data.asks, data.bids

            .on 'close', (e) =>
                pg.info "web socket to be.huobi.com closed: #{e}, reconnect."
                @wsnew = null
                await sleep 1000
                do @init_new

    init_old: () ->
        sock = new WebSocket('wss://api.huobi.com/ws')
            .on 'message', (data) =>
                data = JSON.parse await unzip data

                switch
                    when 'ping' of data
                        sock.send JSON.stringify pong: data.ping
                    when 'id' of data
                        @ch[data.id]? data
                    when 'ch' of data
                        @ch[data.ch] data.tick
                    else
                        pg.warn "server send unknown message #{data}"

            .on 'open', () =>
                pg.info "web socket connected: api.huobi.com"
                @wsold = sock
                ['btc', 'ltc'].forEach (currency) =>
                    id = @register ({status}) -> pg.warn "subscription failed" if status is 'error'
                    sock.send JSON.stringify sub: "market.#{currency}cny.depth.step0", id: id
                    @ch["market.#{currency}cny.depth.step0"] = (data) ->
                        pg.saveDepth currency, data.asks, data.bids

            .on 'close', (e) =>
                pg.info "web socket to api.huobi.com closed: #{e}, reconnect."
                @wsold = null
                await sleep 1000
                do @init_old

    query: (currency, retry=4) ->
        new Promise (resolve, reject) =>
            if retry < 0
                pg.warn "web socket broken"
                return reject new Error "web socket broken"

            sock = if currency in ['etc', 'eth'] then @wsnew else @wsold

            if sock?
                id = @register resolve
                sock.send JSON.stringify req: "market.#{currency}cny.trade.detail", id: id
            else
                await sleep 400
                @query currency, retry - 1
                    .then resolve
                    .catch reject

['btc', 'ltc', 'etc', 'eth'].forEach (currency, i) ->
    pg.alignInterval 15, i, ->
        data = await ws.query currency

        return pg.warn "huobi responds error: #{JSON.strinify data}" if data.status is 'error'

        batch = data.data

        if not lastid[currency]?
            lowest = (batch.sort (x,y) -> x.id - y.id)[0]
            lastSync = await pg.getLastSync currency

            if lastSync?
                {id, n} = JSON.parse lastSync

                if lowest.id <= id + 1
                    candle[currency] = n + 1
                    lastid[currency] = id

            if not lastid[currency]?
                n = pg.candleTime lowest.ts
                candle[currency] = n + 1
                lastid[currency] = (x.id for x in batch when pg.candleTime(x.ts) is n).sort().pop()

        if (batch.some (x) -> x.id <= lastid[currency])
            batch = batch.filter (x) -> x.id > lastid[currency]
            return if batch.length is 0
        else
            pg.warn "huobi #{currency} #{candle[currency]} some data lost"
            lowest = (batch.sort (x,y) -> x.id - y.id)[0]
            candle[currency] = 1 + pg.candleTime lowest.ts

        trades[currency] = trades[currency].concat batch
        lastid[currency] = (x.id for x in batch).sort().pop()

        period = pg.secondTime candle[currency] + 1

        if (batch.some (x) -> x.ts >= period)
            candleTrades = trades[currency].filter (x) -> pg.candleTime(x.ts) is candle[currency]

            if candleTrades.length > 0
                latest = (x.id for x in candleTrades).sort().pop()
                pg.saveCandle currency, pg.createCandle candleTrades, candle[currency]
                pg.setLastSync currency, id: latest, n: candle[currency]

            trades[currency] = trades[currency].filter (x) -> x.ts >= period
            candle[currency] += 1

do ws.init_new
do ws.init_old
