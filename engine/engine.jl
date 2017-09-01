using RedisAlchemy
using OhMyJulia
using Fire

const conn = RedisConnectionPool(db=1)
set_default_redis_connection(conn)

const exchange_list = "btctrade", "chbtc", "huobi", "jubi", "okcoin"
const coin_list     = "btc", "ltc", "etc", "eth"

include("req.jl")
include("balance.jl")
include("trade.jl")
include("risk.jl")
