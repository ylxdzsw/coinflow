PiggySensor = require './piggy'
WebSocket   = require 'ws'

util = require 'util'
sleep = util.promisify setTimeout

pg = new PiggySensor 'okex'

okex =
    init_depth: () ->
        @ws = new WebSocket('wss://real.okex.com:10441/websocket')
            .on 'message', (msg) =>
                @alive = true
                return if msg is '{"event":"pong"}'

                [{channel, data}] = JSON.parse msg

                switch channel
                    when 'addChannel'
                        pg.info msg if data.result isnt true
                    when 'ok_sub_spot_bcc_btc_depth_20'
                        @update_depth 'bcc_btc', data.asks, data.bids
                    when 'ok_sub_spot_ltc_btc_depth_20'
                        @update_depth 'ltc_btc', data.asks, data.bids
                    when 'ok_sub_spot_eth_btc_depth_20'
                        @update_depth 'eth_btc', data.asks, data.bids
                    when 'ok_sub_spot_etc_btc_depth_20'
                        @update_depth 'etc_btc', data.asks, data.bids
                    else
                        pg.info "unknown message #{msg}"

            .on 'open', () =>
                pg.info "web socket connected"
                @connected = @alive = true
                ['bcc_btc','ltc_btc','eth_btc','etc_btc'].forEach (pair) =>
                    @ws.send JSON.stringify event: 'addChannel', channel: "ok_sub_spot_#{pair}_depth_20"

            .on 'close', (e) =>
                pg.info "web socket closed: #{e}, reconnecting"
                @connected = false
                await sleep 1000
                do @init_depth

    update_depth: (pair, asks, bids) ->
        return if not @vol?[pair]?

        find_price = (amount, list) ->
            i = 0

            while i < list.length && amount >= 0
                amount -= list[i++][1]

            list[i-1][0]

        ask = find_price @vol[pair], asks.sort (x, y) -> x[0] - y[0]
        bid = find_price @vol[pair], bids.sort (x, y) -> y[0] - x[0]
        pair = pair.replace '_', ''

        pg.yieldPrice pair, ask, bid

    init_kline: () ->
        @vol = {}
        do okex.sync_kline

        pg.alignInterval 300, 5, () ->
            do okex.sync_kline

    sync_kline: () ->
        ['bcc_btc','ltc_btc','eth_btc','etc_btc'].forEach (pair) =>
            candles = await pg.get "https://www.okex.com/api/v1/kline.do?symbol=#{pair}&type=5min&size=865"
            v = candles.sort (x, y) -> y[0] - x[0]
                       .map (x) -> parseFloat x[5]
            base = v.reduce (x, y) -> x + y
            crit = 3*v[0] + 2*v[1] + 2*v[2] + v[3] + v[4] + v[5] + v[287] + 2*v[288] + v[289] + v[575] + 2*v[576] + v[577] + 2*v[864]
            @vol[pair] = 0.4 * (base / 1000 + crit / 20)

do okex.init_depth
do okex.init_kline

pg.alignInterval 10, 0, () ->
    return if not okex.connected

    if okex.alive
        okex.alive = false
        okex.ws.send JSON.stringify event: 'ping'
    else
        do okex.ws.terminate
