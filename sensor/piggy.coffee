fs    = require 'fs'
util  = require 'util'
redis = require 'redis'

db    = redis.createClient db: 1
sleep = util.promisify setTimeout

rediserr = (err) -> throw err if err?

module.exports = class PiggySensor
    constructor: (@name, @debug=false) ->
        @logfile = fs.createWriteStream "/var/piggy/#{@name}.log", flags: 'a'
        do @startHeartbeating

    stderr: (prefix, msg) ->
        console.error "#{prefix}:", (new Date).toLocaleTimeString(), msg

    log: (msg) -> @stderr "LOG", msg if @debug
    info: (msg) -> @stderr "INFO", msg
    warn: (msg) -> @stderr "WARNING", msg

    alignInterval: (time, f) ->
        time *= 1000
        now = Date.now()
        n = now // time

        await sleep time * (n+1) - now
        @alignInterval time, f if f n isnt false

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
            .exec rediserr
        @logfile.write candle + '\n'
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
