#!/usr/bin/env julia

using Fire
using RedisAlchemy

const conn = RedisConnection(db=1)

"flush redis db 1 and import configures from file"
@main function init(conf="/etc/piggy.conf")
    exec(conn, "flushdb")
    for line in eachline(conf)
        key, value = strip.(split(line, '='))
        exec(conn, "set", key, value)
    end
end

@main function start(service="sensor")

end
