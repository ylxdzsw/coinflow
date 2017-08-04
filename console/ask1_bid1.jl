using OhMyJulia
using RedisAlchemy
using JSON

set_default_redis_connection(RedisConnectionPool(db=1))

while true
    buffer = IOBuffer()
    println(buffer, "\n\t   ", now())
    for currency in ("btc", "ltc", "etc", "eth")
        println(buffer, "\n                     ", currency)
        for exchange in ("btctrade", "chbtc", "huobi", "jubi", "okcoin") @when !(currency == "etc" && exchange == "okcoin")
            ask1 = RedisString("sensor/$exchange.$currency.depth.ask")[] |> JSON.parse |> car |> car
            bid1 = RedisString("sensor/$exchange.$currency.depth.bid")[] |> JSON.parse |> car |> car
            @printf(buffer, "\t%9s  %.2f  %.2f\n", exchange, ask1, bid1)
        end
    end
    write(STDOUT, "\033c", String(take!(buffer)))
    sleep(.5)
end
