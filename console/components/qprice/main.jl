@resource qprice <: root let
    :mixin => defaultmixin
    :GET => begin
        readstring(`nattoppet $(rel"main.jade")`)
    end
end

@resource qprice_data <: qprice let
    :mixin => defaultmixin
    :route => "data"
    :GET | json => begin
        Dict(
            coin => Dict(
                exchange => let
                    candles = map(JSON.parse, RedisList{String}("sensor/$exchange.$coin.candle")[:])
                    candles = filter(x->x["n"] > candletime() - 144, candles) # last 12 hours
                    Dict(
                        "n" => map(x->x["n"], candles),
                        "q1" => map(x->x["q"][2], candles),
                        "q3" => map(x->x["q"][4], candles),
                    )
                end
                for exchange in ("chbtc", "huobi", "okcoin", "btctrade", "jubi")
                if !(exchange == "okcoin" && coin == "etc")
            )
            for coin in ("btc", "ltc", "etc", "eth")
        )
    end
end
