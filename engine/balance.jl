# cash, frozen, plan = balance["huobi"]["cny"]
const balance = Dict(
    exchange => Dict(
        coin => fill(0., 3) for coin in (coin_list..., "cny")
    ) for exchange in exchange_list
)

function sync_balance(exchange, check=true)
    data = exchange == "chbtc"    ? get_chbtc_balance() :
           exchange == "huobi"    ? get_huobi_balance() :
           exchange == "okcoin"   ? get_okcoin_balance() :
           exchange == "btctrade" ? get_btctrade_balance() :
           exchange == "jubi"     ? get_jubi_balance() :
           error("unknown exchange $exchange")

    data == nothing && return

    for coin in (coin_list..., "cny")
        cash, frozen = data[coin]
        balance[exchange][coin][1] = cash
        balance[exchange][coin][2] = frozen
        # TODO: check the difference
    end
end

function get_chbtc_balance()
    data = req_chbtc("/getAccountInfo", "method=getAccountInfo&accesskey=$chbtc_token")

    if get(data, "code", 1000) != 1000
        return warn("chbtc returns $data")
    end

    cash, frozen = data["result"]["balance"], data["result"]["frozen"]

    getamount(x, coin) = parse(Float64, x[uppercase(coin)]["amount"])

    Dict(coin => (getamount(cash, coin), getamount(frozen, coin)) for coin in (coin_list..., "cny"))
end

function get_huobi_balance()
    account_id = RedisString("huobi.account.id")[]

    data = req_huobi_new("/account/accounts/$account_id/balance", Dict())

    if data["status"] != "ok"
        return warn("huobi returns $data")
    end

    list = data["data"]["list"]

    find(c, t) = [parse(Float64, x["balance"]) for x in list if x["currency"] == c && x["type"] == t][]

    newapi = Dict(coin => (find(coin, "trade"), find(coin, "frozen")) for coin in ("cny", "etc", "eth"))

    data = req_huobi_old("/get_account_info", Dict("method"=>"get_account_info"))

    merge(newapi, Dict(
        "btc" => (parse(Float64, data["available_btc_display"]), parse(Float64, data["frozen_btc_display"])),
        "ltc" => (parse(Float64, data["available_ltc_display"]), parse(Float64, data["frozen_ltc_display"]))
    ))
end

function get_okcoin_balance()
    data = req_okcoin("/userinfo.do", Dict())

    if "error_code" in keys(data)
        return warn("okcoin returns $data")
    end

    balance, frozen = data["info"]["funds"]["free"], data["info"]["funds"]["freezed"]

    Dict(coin => (parse(Float64, balance[coin]), parse(Float64, frozen[coin])) for coin in (coin_list..., "cny"))
end

function get_btctrade_balance()
    data = req_btctrade("/balance", Dict())

    if !get(data, "result", true)
        return warn("btctrade returns $data")
    end

    Dict(coin => (parse(Float64, data["$(coin)_balance"]), parse(Float64, data["$(coin)_reserved"])) for coin in (coin_list..., "cny"))
end

function get_jubi_balance()
    data = req_jubi("/balance", Dict())

    if !get(data, "result", true)
        return warn("jubi returns $data")
    end

    Dict(coin => (Float64(data["$(coin)_balance"]), Float64(data["$(coin)_lock"])) for coin in (coin_list..., "cny"))
end


