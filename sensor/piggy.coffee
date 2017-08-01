fs    = require 'fs'
util  = require 'util'
http  = require 'http'
https = require 'https'
redis = require 'redis'

dir   = "/var/piggy"
db    = redis.createClient db: 1
sleep = util.promisify setTimeout

throwerr = (err) -> console.error err if err?

module.exports = class Piggy
    constructor: (@name, @debug=false) ->
        do @startHeartbeating

    stderr: (prefix, msg) ->
        console.error "#{prefix}:", (new Date).toLocaleTimeString(), msg

    log: (msg) -> @stderr "LOG", msg if @debug
    info: (msg) -> @stderr "INFO", msg
    warn: (msg) -> @stderr "WARNING", msg

    get: (url, attempt=3, proto=if url.startsWith 'https' then https else http) ->
        new Promise (resolve, reject) =>
            retry = (msg) =>
                @info msg
                @get url, attempt - 1, proto
                    .then resolve
                    .catch reject

            proto.get url, (res) =>
                if res.statusCode isnt 200
                    do res.resume # consume response data to free up memory
                    return if attempt > 0
                        retry "Request failed with status #{res.statusCode}, retrying"
                    else
                        reject new Error "Request failed with status #{res.statusCode}"

                data = ""
                res.setEncoding 'utf8'
                res.on 'data', (chunk) -> data += chunk
                res.on 'end', ->
                    try
                        resolve JSON.parse data
                    catch e
                        if attempt > 0
                            retry "Request failed with invalid JSON response, retrying"
                        else
                            reject new Error "Request failed with invalid JSON response #{data}"
            .on 'error', (e) ->
                if attempt > 0
                    retry "request failed: #{e.message}, retrying"
                else
                    reject e

    alignInterval: (sec, f) ->
        time = sec * 1000
        now = Date.now()
        n = now // time + 1

        await sleep time * n - now
        shouldContinue = f n
        @alignInterval sec, f if shouldContinue isnt false

    startHeartbeating: ->
        @alignInterval 20, (n) =>
            db.set "status/#{@name}.alive", n, 'EX', 25

    notify: do ->
        conn = do redis.createClient
        (channel, msg="") ->
            conn.publish channel, msg

    createCandle: (trades, n) ->
        nt = trades.length
        return if nt is 0
        trades = @aggregateTrades trades

        # first pass: mean and volumn
        mean = 0
        volumn = 0
        for trade in trades
            mean += trade.price * trade.amount
            volumn += trade.amount
        mean /= volumn

        # second pass: variance (standard deviation actually)
        variance = 0
        for trade in trades
            variance += trade.amount * (trade.price - mean) * (trade.price - mean)
        variance = Math.sqrt variance / volumn

        # third pass: quarters
        q = [trades[0].price, 0, 0, 0, trades[trades.length-1].price]
        v = 0
        i = 0
        m = [0.25, 0.5, 0.75].map (x) -> x * volumn
        for trade in trades
            v += trade.amount
            while v >= m[i]
                i += 1
                q[i] = trade.price
                break if i >= 3

        {mean, volumn, variance, q, n, nt}

    saveCandle: (candle, currency) ->
        candle = JSON.stringify candle
        db.multi()
            .lpush "sensor/#{@name}.#{currency}.candle", candle
            .ltrim "sensor/#{@name}.#{currency}.candle", 0, 255
            .exec throwerr
        fs.appendFile "#{dir}/#{@name}.#{currency}.candles.json", candle + '\n', throwerr
        @notify "channel/#{@name}.#{currency}.candle"

    saveDepth: (asks, bids, currency) ->
        db.multi()
            .set "sensor/#{@name}.#{currency}.depth.ask", JSON.stringify asks
            .set "sensor/#{@name}.#{currency}.depth.bid", JSON.stringify bids
            .set "sensor/#{@name}.#{currency}.depth.fresh", "", 'EX', 10 # expire 10 sec
            .exec throwerr
        @notify "channel/#{@name}.#{currency}.depth"

    aggregateTrades: (trades) ->
        trades.sort (x,y) -> x.price - y.price
        result = []
        for trade in trades
            if result.length > 0
                last = result[result.length-1]
            else
                result.push amount: trade.amount, price: trade.price
                continue

            if last.price == trade.price
                last.amount += trade.amount
            else
                result.push amount: trade.amount, price: trade.price
        result
