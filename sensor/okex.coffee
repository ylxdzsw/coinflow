PiggySensor = require './piggy'
WebSocket   = require 'ws'

util = require 'util'
sleep = util.promisify setTimeout

pg = new PiggySensor 'okex'

okex =
    init: () ->
        @kilne = {}
        @ws = new WebSocket('wss://real.okex.com:10441/websocket')
            .on 'message', (msg) =>
                {channel, data} = JSON.parse msg

                switch channel
                    when 'addChannel'
                        pg.info msg if data.result isnt true
                    when 'ok_sub_spot_bcc_btc_depth_60'
                        @update_depth 'bcc_btc', data.asks, data.bids
                    when 'ok_sub_spot_ltc_btc_depth_60'
                        @update_depth 'ltc_btc', data.asks, data.bids
                    when 'ok_sub_spot_eth_btc_depth_60'
                        @update_depth 'eth_btc', data.asks, data.bids
                    when 'ok_sub_spot_etc_btc_depth_60'
                        @update_depth 'etc_btc', data.asks, data.bids
                    when 'ok_sub_spot_bcc_btc_kline_3min'
                        @update_kline 'bcc_btc', data
                    when 'ok_sub_spot_ltc_btc_kline_3min'
                        @update_kline 'ltc_btc', data
                    when 'ok_sub_spot_eth_btc_kline_3min'
                        @update_kline 'eth_btc', data
                    when 'ok_sub_spot_etc_btc_kline_3min'
                        @update_kline 'etc_btc', data
                    else
                        pg.info "unknown message"

            .on 'open', () =>
                pg.info "web socket connected"
                @connected = true
                ['bcc_btc','ltc_btc','eth_btc','etc_btc'].forEach (pair) =>
                    @ws.send JSON.stringify event: 'addChannel', channel: "ok_sub_spot_#{pair}_depth_20"
                    @ws.send JSON.stringify event: 'addChannel', channel: "ok_sub_spot_#{pair}_kline_3min"

            .on 'close', (e) =>
                pg.info "web socket closed: #{e}, reconnecting"
                @connected = false
                await sleep 1000
                do @init

            .on 'pong', ->
                @alive = true

    update_depth: (pair, asks, bids) ->
        return if not @kline[pair]?

        asks = asks.sort (x, y) -> x[0] - y[0]
        bids = bids.sort (x, y) -> y[0] - x[0]

        k = @kline[pair]
        i = 0

        while k > asks[i++]


    update_kline: (pair, candles) ->

do okex.init

pg.alignInterval 30, 0, () ->
    return if not okex.connected

    if okex.alive
        okex.alive = false
        do okex.ws.ping
    else
        do okex.ws.terminate
