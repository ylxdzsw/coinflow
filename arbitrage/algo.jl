abstract type Fee end

struct RateFee <: Fee
    fee::Float64
end

(x::RateFee)(amount) = amount * x.fee

struct FixedFee <: Fee
    fee::Float64
end

(x::FixedFee)(amount) = x.fee

const fees = Dict{NTuple{3, String}, Fee}((exchange, op, coin) => if (x = SafeRedisString("config/$exchange.fee.$op.$coin.rate")[]; !isnull(x))
    RateFee(parse(Float64, get(x)))
elseif (x = SafeRedisString("config/$exchange.fee.$op.$coin.fixed")[]; !isnull(x))
    FixedFee(parse(Float64, get(x)))
else
    FixedFee(0.)
end for exchange in exchange_list for coin in (coin_list..., "cny") for op in ("make", "take", "draw"))

function seek_chance(currency)
    exs = []

    for ex in exchange_list
        candle = SafeRedisList{String}("sensor/$ex.$currency.candle")[1]
        if !isnull(candle)
            candle = JSON.parse(get(candle))
            push!(exs, (ex, candle["q"][2], candle["q"][4]))
        end
    end

    seller = max(exs..., by=i"2")
    buyer  = min(exs..., by=i"3")

    if buyer[3] < seller[2]
        car(buyer), car(seller)
    else
        nothing
    end
end

# `buy` and `sell` are exchanges where we will buy or sell coins
# returns [(totalrevenue, totalamount, buyprice, sellprice, totalfee, profit, profit rate)]
function calc_profit(currency, buy, sell)
    if exec(conn, "exists", "sensor/$buy.$currency.depth.fresh", "sensor/$sell.$currency.depth.fresh") < 2
        error("lacks latest depth info of $buy or $sell")
    end

    asks = RedisString("sensor/$buy.$currency.depth.ask")[]  |> JSON.parse
    bids = RedisString("sensor/$sell.$currency.depth.bid")[] |> JSON.parse

    i, j, q, p = 1, 1, 0, 0
    result = []
    while i <= length(asks) && j <= length(bids) && car(asks[i]) < car(bids[j])
        a = min(cadr(asks[i]), cadr(bids[j]))
        q += a
        p += a * (car(bids[j]) - car(asks[i]))
        f = fees[(buy, "take", currency)](q * car(asks[i])) +
            fees[(sell, "take", currency)](q * car(bids[j])) +
            fees[(buy, "draw", currency)](q * car(asks[i])) +
            fees[(sell, "draw", "cny")](q * car(bids[j]))
        profit = p - f
        profit_rate = profit / (q * car(asks[i]) + q * car(bids[j]))
        push!(result, (p, q, car(asks[i]), car(bids[j]), f, profit, profit_rate))

        if asks[i][2] == a
            i += 1
        else
            asks[i][2] -= a
        end

        if bids[j][2] == a
            j += 1
        else
            bids[j][2] -= a
        end
    end

    return result
end
