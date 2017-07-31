fs    = require 'fs'
util  = require 'util'
http  = require 'http'
redis = require 'redis'

dir   = "/var/piggy"
db    = redis.createClient db: 1
sleep = util.promisify setTimeout

throwerr = (err) -> throw err if err?

module.exports = class Piggy
    constructor: (@name, @debug=false) ->
        do @startHeartbeating

    stderr: (prefix, msg) ->
        console.error "#{prefix}:", (new Date).toLocaleTimeString(), msg

    log: (msg) -> @stderr "LOG", msg if @debug
    info: (msg) -> @stderr "INFO", msg
    warn: (msg) -> @stderr "WARNING", msg

    get: (url) ->
        new Promise (resolve, reject) ->
            http.get url, (res) ->
                if res.statusCode isnt 200
                    do res.resume # consume response data to free up memory
                    return reject new Error "Request failed with status #{res.statusCode}"

                data = ""
                res.setEncoding 'utf8'
                res.on 'data', (chunk) -> data += chunk
                res.on 'end', ->
                    try
                        resolve JSON.parse data
                    catch e
                        reject new Error "Request failed with invalid JSON response #{data}"
            .on 'error', reject

    alignInterval: (sec, f) ->
        time = sec * 1000
        now = Date.now()
        n = now // time

        await sleep time * (n+1) - now
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
            .lpush "sensor/#{@name}.#{currency}.candles", candle
            .ltrim "sensor/#{@name}.#{currency}.candles", 0, 255
            .exec throwerr
        fs.appendFile "#{dir}/#{@name}.#{currency}.candles.json", candle + '\n', throwerr
        @notify "channel/#{@name}.#{currency}.candle"

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
