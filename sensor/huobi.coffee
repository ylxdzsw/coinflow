PiggySensor = require './piggy'
WebSocket   = require 'ws'

util = require 'util'
zlib = require 'zlib'

pg = new PiggySensor 'huobi'

unzip = util.promisify zlib.unzip
sleep = util.promisify setTimeout

getid = do (c=0) -> () -> 'id'+c++

pairs = ['ethbtc', 'ltcbtc', 'etcbtc', 'bccbtc']

huobi =
    init_depth: () ->
        @ws = new WebSocket('wss://api.huobi.pro/ws')
            .on 'message', (msg) =>
                @alive = true
                data = JSON.parse await unzip msg
                return @ws.send JSON.stringify pong: data.ping if 'ping' of data
                @update_depth m[1], data.tick.asks, data.tick.bids if m = data.ch?.match /market.(\w{6}).depth.step1/ # step1 precision: 5 digits after dot

            .on 'open', () =>
                pg.info "web socket connected"
                @connected = @alive = true
                pairs.forEach (pair) =>
                    @ws.send JSON.stringify sub: "market.#{pair}.depth.step1", id: do getid

            .on 'close', (e) =>
                pg.info "web socket closed: #{e}, reconnecting"
                @connected = false
                await sleep 1000
                do @init

    update_depth: (pair, asks, bids) ->
        return if not @vol?[pair]?

        find_price = (amount, list) ->
            i = 0

            while i < list.length && amount >= 0
                amount -= list[i++][1]

            list[i-1][0]

        ask = find_price @vol[pair], asks.sort (x, y) -> x[0] - y[0]
        bid = find_price @vol[pair], bids.sort (x, y) -> y[0] - x[0]

        pg.yieldPrice pair, ask, bid

    init_kline: () ->
        @vol = {}
        do huobi.sync_kline

        pg.alignInterval 300, 5, () ->
            do huobi.sync_kline

    sync_kline: () ->
        pairs.forEach (pair) =>
            candles = await pg.get "https://api.huobi.pro/market/history/kline?symbol=#{pair}&period=5min&size=865"
            v = candles.data.sort (x, y) -> y.id - x.id
                            .map (x) -> parseFloat x.amount
            base = v.reduce (x, y) -> x + y
            crit = 3*v[0] + 2*v[1] + 2*v[2] + v[3] + v[4] + v[5] + v[287] + 2*v[288] + v[289] + v[575] + 2*v[576] + v[577] + 2*v[864]
            @vol[pair] = 0.5 * (base / 1000 + crit / 20)

do huobi.init_depth
do huobi.init_kline

pg.alignInterval 10, 0, () ->
    return if not huobi.connected

    if huobi.alive
        huobi.alive = false
    else
        do huobi.ws.terminate
