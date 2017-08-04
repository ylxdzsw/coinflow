using RedisAlchemy
using OhMyJulia
using JSON
using Fire

const conn = RedisConnectionPool(db=1)
set_default_redis_connection(conn)

const exchange_list = "btctrade", "chbtc", "huobi", "jubi", "okcoin"
const coin_list = "btc", "ltc", "etc", "eth"

const chances = [ [currency, exchange_list[a], exchange_list[b], 0]
                  for currency in coin_list for a in 1:length(exchange_list)-1 for b in a+1:length(exchange_list)
                  if !(currency == "etc" && (exchange_list[a] == "okcoin" || exchange_list[b] == "okcoin")) ]

include("algo.jl")

const wechat_channel = RedisCondition("channel/wechat.msg")

function notify_new(currency, buy, sell, p, q, ask, bid, f, profit, profit_rate)
    p, ask, bid, f, profit = round.((p, ask, bid, f, profit), 2)
    q, profit_rate = round.((q, profit_rate), 4)
    total = round(profit / profit_rate, 2)
    msg = "发现交易机会：从 $buy 以 $ask 的价格购买 $q $currency, 在 $sell 以 $bid 的价格卖出，总收益 $p，总手续费 $f，利润 $profit，动用资金 $total，利润率 $profit_rate"
    notify(wechat_channel, msg)
end

function notify_cancel(currency, buy, sell)
    notify(wechat_channel, "从 $buy 买 $currency 卖到 $sell 的机会已消失")
end

function cancel_chance(chance)
    currency, a, b, last = chance
    if last > 0
        notify_cancel(currency, a, b)
    elseif last < 0
        notify_cancel(currency, b, a)
    end
    chance[end] = 0
end

@main function main()
    while true
        for chance in chances
            currency, a, b, last = chance

            direction = chance_direction(currency, a, b)

            buy, sell = direction > 0 ? (a, b) :
                        direction < 0 ? (b, a) :
                        (cancel_chance(chance); continue)

            trades = calc_profit(currency, buy, sell)

            if isempty(trades)
                cancel_chance(chance)
                continue
            end

            best = findmax(i"6".(trades))

            if car(best) < 0
                cancel_chance(chance)
                continue
            end

            best = trades[cadr(best)]

            if best[end] < 0.0008 # min profit rate
                continue # don't cancel the chance
            end

            if last != direction
                notify_new(currency, buy, sell, best...)
            end

            chance[end] = direction
        end
        sleep(2)
    end
end
