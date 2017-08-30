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
    constructor: (@name) ->
        do @startHeartbeating

    stderr: (prefix, msg) ->
        console.error "#{prefix}:", (new Date).toLocaleTimeString()[0...8], msg

    info: (msg) -> @stderr "INFO", msg
    warn: (msg) -> @stderr "WARN", msg

    get: (url, attempt=2, proto=if url.startsWith 'https' then https else http) ->
        new Promise (resolve, reject) =>
            retry = (msg) =>
                @info msg
                await sleep 200
                @get url, attempt - 1, proto
                    .then resolve
                    .catch reject

            proto.get url, (res) =>
                if res.statusCode isnt 200
                    do res.resume # consume response data to free up memory
                    return if res.statusCode is 204
                        reject new Error "#{url} responses #{res.statusCode}"
                    else if attempt > 0
                        retry "Request failed with status #{res.statusCode}, retrying"
                    else
                        @warn "request to #{url} failed 3 times, giving up"
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
                            @warn "request to #{url} failed 3 times, giving up"
                            reject new Error "Request failed with invalid JSON response #{data}"
            .on 'error', (e) =>
                if attempt > 0
                    retry "request failed: #{e.message}, retrying"
                else
                    @warn "request to #{url} failed 3 times, giving up"
                    reject e

    alignInterval: (sec, phase, f) ->
        time = sec * 1000
        now = Date.now() - phase * 1000
        n = now // time + 1

        await sleep time * n - now
        shouldContinue = f n
        @alignInterval sec, phase, f if shouldContinue isnt false

    startHeartbeating: ->
        @alignInterval 20, 0, (n) =>
            db.set "status/#{@name}.alive", n, 'EX', 25

    notify: do ->
        conn = do redis.createClient
        (channel, msg="") ->
            conn.publish channel, msg

    createCandle: (trades, n) ->
        nt = trades.length
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

    saveCandle: (currency, candle) ->
        candle = JSON.stringify candle
        db.multi()
            .lpush "sensor/#{@name}.#{currency}.candle", candle
            .ltrim "sensor/#{@name}.#{currency}.candle", 0, 2016 # 7 days
            .exec throwerr
        fs.appendFile "#{dir}/#{@name}.#{currency}.candles.json", candle + '\n', throwerr
        @notify "channel/#{@name}.#{currency}.candle"

    saveDepth: (currency, asks, bids) ->
        asks.sort ([p1], [p2]) -> p1 - p2
        bids.sort ([p1], [p2]) -> p2 - p1
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

    setLastSync: (currency, info) ->
        db.set "sensor/#{@name}.#{currency}.lastsync.id", JSON.stringify info

    getLastSync: (currency) ->
        new Promise (resolve, reject) =>
            db.get "sensor/#{@name}.#{currency}.lastsync.id", (err, data) ->
                if err? then reject err else resolve data

    candleTime: (time=Date.now()//1000) -> time // 300 - 5000000

    secondTime: (n) -> if n? then 300 * (n + 5000000) else Date.now() // 1000
