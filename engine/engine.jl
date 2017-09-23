using RedisAlchemy
using OhMyJulia
using Fire

const conn = RedisConnectionPool(db=1)
set_default_redis_connection(conn)

const exchanges = "okex", "huobi", "bitfinex"
const coins = "bcc", "btc", "ltc", "eth", "etc", "usd"

include("graph.jl")
