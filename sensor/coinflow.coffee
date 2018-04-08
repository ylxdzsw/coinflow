fs    = require 'fs'
util  = require 'util'
http  = require 'http'
https = require 'https'
redis = require 'redis'

pid   = process.pid
dir   = process.env.COINFLOW_HOME
db    = redis.createClient db: 1
sleep = util.promisify setTimeout

throwerr = (err) -> throw err if err?

module.exports = class Sensor
    constructor: (@name) ->
        @logfile = fs.openSync "#{dir}/#{@name}.sensor.log", "a"

        process.on 'uncaughtException', (err) =>
            @log 'warn', if (err && err.stack) then err.stack else err

        db.on 'error', (err) =>
            @log 'warn', err

        do @startHeartbeating

    log: (level, msg) ->
        if level in ['info', 'warn', 'notif']
            db.rpush "log/#{@name}.sensor", "#{level} #{msg}"
            db.rpush "notif/#{@name}.sensor", msg if level is 'notif'
        time = (new Date).toISOString().match(/(.*)T(.*)\./)
        @logfile.write "#{time[1]} #{time[2]} #{level}: #{msg}\n", throwerr

    get: (url, attempt=2, proto=if url.startsWith 'https' then https else http) ->
        new Promise (resolve, reject) =>
            retry = (msg) =>
                @log 'debug', msg

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
                        @log 'warn', "request to #{url} failed 3 times, giving up"
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
                            @log 'warn', "request to #{url} failed 3 times, giving up"
                            reject new Error "Request failed with invalid JSON response #{data}"
            .on 'error', (e) =>
                if attempt > 0
                    retry "request failed: #{e.message}, retrying"
                else
                    @log 'warn', "request to #{url} failed 3 times, giving up"
                    reject e

    alignInterval: (sec, phase, f) ->
        time = sec * 1000
        now = Date.now() - phase * 1000
        n = now // time + 1

        await sleep time * n - now
        f n
        @alignInterval sec, phase, f

    startHeartbeating: ->
        @alignInterval 5, 0, () =>
            db.set "status/#{@name}.pid", pid, 'EX', 12

    notify: do ->
        conn = do redis.createClient
        conn.on 'error', (err) => @log 'warn', err
        (channel, msg="") ->
            conn.publish channel, msg

    yieldPrice: (pair, ask, bid) ->
        @log 'data', JSON.stringify { pair, ask, bid }
        db.multi()
            .set "market/#{@name}.#{pair}.price.ask", ask, 'EX', 15
            .set "market/#{@name}.#{pair}.price.bid", bid, 'EX', 15
            .exec throwerr
        @notify "channel/#{@name}.#{pair}.price"
        db.rpush 'data/order_price', { pair, ask, bid, time: Date.now() // 1000, exchange: @name }
