using RedisAlchemy
using OhMyJulia
using JSON
using Fire

const conn = RedisConnectionPool(db=1)
set_default_redis_connection(conn)

const exchange_list = "btctrade", "chbtc", "huobi", "jubi", "okcoin"
const coin_list = "btc", "ltc", "etc", "eth"

include("algo.jl")

const wechat_channel = RedisCondition("channel/wechat.msg")

function notify_wechat(currency, buy, sell, p, q, ask, bid, f, profit, profit_rate)
    p, ask, bid, f, profit = round.((p, ask, bid, f, profit), 2)
    q, profit_rate = round.((q, profit_rate), 4)
    total = round(profit / profit_rate, 2)
    msg = "发现交易机会：从 $buy 以 $ask 的价格购买 $q $currency, 在 $sell 以 $bid 的价格卖出，总收益 $p，总手续费 $f，利润 $profit，动用资金 $total，利润率 $profit_rate"
    notify(wechat_channel, msg)
end

@main function main()
    while true
        for currency in coin_list
            chance = seek_chance(currency)
            if chance != nothing
                buy, sell = chance
                trades = calc_profit(currency, buy, sell)

                if isempty(trades)
                    continue
                else
                    best = findmax(i" 6".(trades))
                end

                if car(best) < 0
                    continue
                else
                    best = trades[cadr(best)]
                end

                if best[end] < 0.001 # min profit rate
                    continue
                end

                notify_wechat(currency, buy, sell, best...)
            end
        end
        sleep(120)
    end
end
