Sensor    = require './coinflow'
WebSocket = require 'ws'

util = require 'util'
sleep = util.promisify setTimeout

cf = new Sensor 'bitfinex'

bitfinex =
    init_depth: () ->
        @book = {}
        @ws = new WebSocket('wss://api.bitfinex.com/ws/2')
            .on 'message', (msg) =>
                @alive = true
                data = JSON.parse msg

                switch data.event
                    when 'info'
                        do @ws.terminate if data.code in [20051, 20061]
                    when 'ping'
                        @ws.send '{"event":"pong"}'
                    when 'subscribed'
                        @book[data.chanId] = symbol: data.symbol, asks: {}, bids: {}
                    else
                        [id, data] = data
                        @update_depth id, data if data isnt 'hb'

            .on 'open', () =>
                cf.info "web socket connected"
                @connected = @alive = true
                ['tBTCUSD','tLTCUSD','tLTCBTC','tETHUSD','tETHBTC','tETCUSD','tETCBTC'].forEach (pair) =>
                    @ws.send JSON.stringify event: 'subscribe', channel: 'book', symbol: pair, prec: 'P1', freq: 'F1'

            .on 'close', (e) =>
                cf.info "web socket closed: #{e}, reconnecting"
                @connected = false
                await sleep 1000
                do @init_depth

            .on 'error', (e) =>
                if e.message.includes '403'
                    await sleep 200
                    do @init_depth
                else
                    throw e

    update_depth: (id, data) ->
        if data[0].length # snapshot
            for x in data
                @update_depth id, x
        else
            if @last isnt id
                @yield_price @last if @last of @book

            [price, count, amount] = data

            if count is 0
                if amount > 0
                    delete @book[id].bids[price]
                else
                    delete @book[id].asks[price]
            else
                if amount > 0
                    @book[id].bids[price] = amount
                else
                    @book[id].asks[price] = -amount

        @last = id

    yield_price: (id) ->
        {symbol, asks, bids} = @book[id]
        return if not @vol?[symbol]?

        pair = symbol[1..].toLowerCase()
        asks = ([level, asks[level]] for level of asks)
        bids = ([level, bids[level]] for level of bids)

        find_price = (amount, list) ->
            i = 0

            while i < list.length && amount >= 0
                amount -= list[i++][1]

            list[i-1][0]

        ask = find_price @vol[symbol], asks.sort (x, y) -> x[0] - y[0]
        bid = find_price @vol[symbol], bids.sort (x, y) -> y[0] - x[0]

        cf.yieldPrice pair, ask, bid

    init_kline: () ->
        @vol = {}
        do bitfinex.sync_kline

        cf.alignInterval 300, 5, () ->
            do bitfinex.sync_kline

    sync_kline: () ->
        ['tBTCUSD','tLTCUSD','tLTCBTC','tETHUSD','tETHBTC','tETCUSD','tETCBTC'].forEach (pair) =>
            candles = await cf.get "https://api.bitfinex.com/v2/candles/trade:5m:#{pair}/hist?limit=865"
            v = candles.sort (x, y) -> y[0] - x[0]
                       .map (x) -> x[5]
            base = v.reduce (x, y) -> x + y
            crit = 3*v[0] + 2*v[1] + 2*v[2] + v[3] + v[4] + v[5] + v[287] + 2*v[288] + v[289] + v[575] + 2*v[576] + v[577] + 2*v[864]
            @vol[pair] = 0.35 * (base / 1000 + crit / 20)

do bitfinex.init_depth
do bitfinex.init_kline

cf.alignInterval 10, 0, () ->
    return if not bitfinex.connected

    if bitfinex.alive
        bitfinex.alive = false
    else
        do bitfinex.ws.terminate
