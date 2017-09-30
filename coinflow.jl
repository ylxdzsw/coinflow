#!/usr/bin/env julia

using Fire
using RedisAlchemy
using OhMyJulia

const conn = RedisConnection(db=1)

"flush redis db 1 and import configures from file"
@main function init(conf="/etc/coinflow.conf")
    # exec(conn, "flushdb")
    for line in eachline(conf) @when !startswith(line, '#') && '=' in line
        key, value = strip.(split(line, '='))
        exec(conn, "set", "config/$key", value)
    end
end

@main function start(service="sensors")
    if startswith("sensors", service)
        @sync for file in ("okex.coffee", "huobi.coffee", "bitfinex.coffee")
            @async run(`coffee sensor/$file`)
        end
    end
end
