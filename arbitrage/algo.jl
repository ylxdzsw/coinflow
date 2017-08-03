abstract type Fee end

struct RateFee
    fee::Float64
end

(x::RateFee)(amount) = amount * x.fee

struct FixedFee
    fee::Float64
end

(x::FixedFee)(amount) = x.fee

const fees =


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
function calc_profit(currency, buy, sell)
    if exec(conn, "exists", "sensor/$buy.$currency.depth.fresh", "sensor/$sell.$currency.depth.fresh") < 2
        error("lacks latest depth info of $buy or $sell")
    end

    asks = RedisString("sensor/$buy.$currency.depth.ask")[]  |> JSON.parse
    bids = RedisString("sensor/$sell.$currency.depth.bid")[] |> JSON.parse

    i, j, q, p = 1, 1, 0, []
    while i <= length(asks) && j <= length(bids) && car(asks[i]) < car(bids[i])
        a = min(cadr(asks[i]), cadr(bids[j]))
        q += a
        push!(p, (q, cadr(p[end]) + a * (car(asks[j]) - car(bids[i]))))

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

    return p
end
