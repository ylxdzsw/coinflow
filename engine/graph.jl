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
    ("bitfinex", "etc", "usd")
]

const drawables = [
    ("okex", "btc"),
    ("okex", "ltc"),
    ("okex", "eth"),
    ("okex", "etc"),

    ("huobi", "bcc"),
    ("huobi", "eth"),
    ("huobi", "etc"),

    ("bitfinex", "btc"),
    ("bitfinex", "ltc"),
    ("bitfinex", "eth"),
    ("bitfinex", "etc")
]

const exchanges = "okex", "huobi", "bitfinex"

const coins = "bcc", "btc", "ltc", "eth", "etc"

tradeable(ex, c1, c2) = (ex, c1, c2) in trade_pairs || (ex, c2, c1) in trade_pairs

const cycles = let x = []
    for exchange in exchanges, coin in coins
        function f(p, path=(), depth=5)
            if !isempty(path) && p == car(path)
                return push!(x, path)
            elseif depth <= 0
                return
            end

            npath = (path..., p)
            ndepth = depth - 1

            if p in drawables
                for nex in exchanges
                    np = nex, cadr(p)
                    if !(np in cdr(npath))
                        f(np, npath, ndepth)
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

    filter(x->length(x)>1, x)
end
