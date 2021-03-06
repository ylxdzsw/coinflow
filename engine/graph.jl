const trade_pairs = [
    ("okex", "bcc", "btc"),
    ("okex", "ltc", "btc"),
    ("okex", "eth", "btc"),
    ("okex", "etc", "btc"),

    ("huobi", "bcc", "btc"),
    ("huobi", "ltc", "btc"),
    ("huobi", "eth", "btc"),
    ("huobi", "etc", "btc"),

    ("bitfinex", "btc", "usd"),
    ("bitfinex", "ltc", "btc"),
    ("bitfinex", "ltc", "usd"),
    ("bitfinex", "eth", "btc"),
    ("bitfinex", "eth", "usd"),
    ("bitfinex", "etc", "btc"),
    ("bitfinex", "etc", "usd"),
    ("bitfinex", "bch", "btc"),
    ("bitfinex", "bch", "usd"),
    ("bitfinex", "bch", "eth")
]

const drawables = [
    ("okex", "btc"),
    ("okex", "ltc"),
    ("okex", "eth"),
    ("okex", "etc"),
    ("okex", "bcc"),

    ("huobi", "bcc"),
    ("huobi", "eth"),
    ("huobi", "etc"),

    ("bitfinex", "btc"),
    ("bitfinex", "ltc"),
    ("bitfinex", "eth"),
    ("bitfinex", "etc"),
    ("bitfinex", "bch")
]

const paths = [] # (ex1, coin1, ex2, coin2, :draw | :trade, f -> rate)

const base_profit_rate_per_trade = 0.0005
const base_profit_rate_per_draw  = 0.001

for (ex, coin1, coin2) in trade_pairs
    fee = parse(Float64, RedisString("config/$ex.fee.take")[])
    buy()  = (1. - fee - base_profit_rate_per_trade) * parse(Float64, RedisString("sensor/$ex.$coin1$coin2.price.ask")[])
    sell() = (1. - fee - base_profit_rate_per_trade) / parse(Float64, RedisString("sensor/$ex.$coin1$coin2.price.bid")[])
    push!(paths, (ex, coin1, ex, coin2, :trade, buy)
    push!(paths, (ex, coin2, ex, coin1, :trade, sell)
end

for (ex, coin) in drawables
    if coin in ("bcc", "bch")

    end

end


tradeable(ex, c1, c2) = (ex, c1, c2) in trade_pairs || (ex, c2, c1) in trade_pairs

const cycles = let x = []
    for exchange in exchanges, coin in coins
        function f(p, path=(), depth=5, drawed=false) # cannot immediatly draw twice
            if !isempty(path) && p == car(path) && length(path) > 2 &&
               !(drawed && cadr(car(path)) == cadr(cadr(path))) &&
               !(depth <= 0 && length(unique(car.(path))) == 1)
                return push!(x, path)
            elseif depth <= 0
                return
            end

            npath = (path..., p)
            ndepth = depth - 1

            if !drawed && p in drawables
                for nex in exchanges
                    np = nex, cadr(p)
                    if !(np in cdr(npath))
                        f(np, npath, ndepth, true)
                    end
                end
            end

            for ncoin in coins
                np = car(p), ncoin
                if !(np in cdr(npath)) && tradeable(p..., ncoin)
                    f(np, npath, ndepth)
                end
            end
        end

        f((exchange, coin))
    end

    unique(Set, x)
end
