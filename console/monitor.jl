using RedisAlchemy
using OhMyJulia
using JSON
using Fire

const conn = RedisConnectionPool(db=1)
set_default_redis_connection(conn)

const exchange_list = "btctrade", "chbtc", "huobi", "jubi", "okcoin"
const coin_list = "btc", "ltc", "etc", "eth"

const chances = [ (currency, exchange_list[a], exchange_list[b])
                  for currency in coin_list for a in 1:length(exchange_list)-1 for b in a+1:length(exchange_list)
                  if !(currency == "etc" && (exchange_list[a] == "okcoin" || exchange_list[b] == "okcoin")) ]

const wechat_channel = RedisCondition("channel/wechat.msg")

const threshold = 0.03

const minvol = Dict(
    "btctrade" => Dict("btc"=>0.03, "ltc"=>1.0,  "etc"=>1.0,  "eth"=>0.1),
    "chbtc"    => Dict("btc"=>0.1,  "ltc"=>1.0,  "etc"=>3.0,  "eth"=>0.1),
    "huobi"    => Dict("btc"=>0.1,  "ltc"=>10.0, "etc"=>10.0, "eth"=>1.0),
    "jubi"     => Dict("btc"=>0.03, "ltc"=>1.0,  "etc"=>1.0,  "eth"=>0.1),
    "okcoin"   => Dict("btc"=>0.1,  "ltc"=>10.0,              "eth"=>1.0)
)

const lastreport = Dict((currency, buy, sell) => 0. for (currency, a, b) in chances for (buy, sell) in ((a, b), (b, a)))

function notify_wechat(currency, buy, sell, ask, bid, rate, msg)
    ask, bid, rate = round.((ask, bid, 100rate), 2)
    notify(wechat_channel, "$currency: $buy 购买价 $ask, $sell 卖出价 $bid, 价格差 $rate% $msg $(round(100threshold))%")
end

function calc_price(currency, exchange, direction)
    if exec(conn, "exists", "sensor/$exchange.$currency.depth.fresh") != 1
        error("lacks depth info of $exchange")
    end

    list = RedisString("sensor/$exchange.$currency.depth.$direction")[] |> JSON.parse
    i, vol = 1, minvol[exchange][currency]

    while i <= length(list) && vol > cadr(list[i])
        i += 1
        vol -= cadr(list[i])
    end

    car(list[i])
end

@main function main()
    while true
        for (currency, a, b) in chances, (buy, sell) in ((a, b), (b, a))
            ask, bid = try
                calc_price(currency, buy, "ask"), calc_price(currency, sell, "bid")
            catch e
                println(e)
                continue
            end

            rate = (bid - ask) / ask

            if rate < threshold
                if lastreport[(currency,buy,sell)] > 0
                    notify_wechat(currency, buy, sell, ask, bid, rate, "向下突破")
                    lastreport[(currency,buy,sell)] = 0
                end
            else
                if lastreport[(currency,buy,sell)] == 0
                    notify_wechat(currency, buy, sell, ask, bid, rate, "向上突破")
                    lastreport[(currency,buy,sell)] = time()
                elseif time() - lastreport[(currency,buy,sell)] > 15 * 60
                    notify_wechat(currency, buy, sell, ask, bid, rate, "仍然超过")
                    lastreport[(currency,buy,sell)] = time()
                end
            end
        end

        sleep(2)
    end
end
