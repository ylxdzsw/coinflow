using RedisAlchemy
using OhMyJulia
using JSON

include("algo.jl")

const conn = RedisConnectionPool(db=1)
set_default_redis_connection(conn)

const exchange_list = "btctrade", "chbtc", "huobi", "jubi", "okcoin"
const coin_list = "btc", "ltc", "etc", "eth"


