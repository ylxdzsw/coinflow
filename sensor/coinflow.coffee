fs    = require 'fs'
util  = require 'util'
http  = require 'http'
https = require 'https'
redis = require 'redis'

dir   = "/var/coinflow"
db    = redis.createClient db: 1
sleep = util.promisify setTimeout

throwerr = (err) -> console.error err if err?

module.exports = class Sensor
    constructor: (@name) ->
        do @startHeartbeating

    info: (msg) ->
        time = (new Date).toISOString().match(/(.*)T(.*)\./)
        fs.appendFile "#{dir}/sensor.log", "#{time[1]} #{time[2]} #{msg}\n", throwerr
        console.error time[2], msg

    get: (url, attempt=2, proto=if url.startsWith 'https' then https else http) ->
        new Promise (resolve, reject) =>
            retry = (msg) =>
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
                        @info "request to #{url} failed 3 times, giving up"
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
                            @info "request to #{url} failed 3 times, giving up"
                            reject new Error "Request failed with invalid JSON response #{data}"
            .on 'error', (e) =>
                if attempt > 0
                    retry "request failed: #{e.message}, retrying"
                else
                    @info "request to #{url} failed 3 times, giving up"
                    reject e

    alignInterval: (sec, phase, f) ->
        time = sec * 1000
        now = Date.now() - phase * 1000
        n = now // time + 1

        await sleep time * n - now
        f n
        @alignInterval sec, phase, f

    startHeartbeating: ->
        @alignInterval 10, 0, (n) =>
            db.set "status/#{@name}.alive", n, 'EX', 25

    notify: do ->
        conn = do redis.createClient
        (channel, msg="") ->
            conn.publish channel, msg

    yieldPrice: (pair, ask, bid) ->
        db.multi()
            .set "sensor/#{@name}.#{pair}.price.ask", ask
            .set "sensor/#{@name}.#{pair}.price.bid", bid
            .exec throwerr
        @notify "channel/#{@name}.#{pair}.price"
