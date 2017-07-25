WebSocket   = require 'ws'
PiggySensor = require './piggy'

ws = new WebSocket "wss://api.chbtc.com:9999/websocket"
ps = new PiggySensor 'chbtc'

ids    = btc: [], ltc: [], etc: [], eth: []
trades = btc: [], ltc: [], etc: [], eth: []

ws.on 'open', () ->
    ws.send JSON.stringify event: 'addChannel', channel: 'btc_cny_trades'
    ws.send JSON.stringify event: 'addChannel', channel: 'ltc_cny_trades'
    ws.send JSON.stringify event: 'addChannel', channel: 'etc_cny_trades'
    ws.send JSON.stringify event: 'addChannel', channel: 'eth_cny_trades'

ws.on 'message', (msg) ->
    try
        data = JSON.parse msg
    catch e
        ps.log data
        ps.warn e
        return

    if 'success' in data && !datza.success
        return ps.warn msg

    switch
        when data.channel.endsWith 'trades'
            onTrade data
        else
            ps.log msg
            ps.warn "unknown channel #{data.channel}"

onTrade = (data) ->
    currency = data.channel[..2]
    for trade in data.data
        if trade.tid not in ids[currency]
            ids[currency].push trade.tid
            trades[currency].push trade

ps.alignInterval 300, (n) ->
    for currency in ['btc', 'ltc', 'etc', 'eth']
        candle = ps.createCandle trades[currency], n
        ps.saveCandle candle, currency
