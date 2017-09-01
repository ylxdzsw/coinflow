using Requests: get, post, statuscode
using Nettle
using JSON

const chbtc_key   = hexdigest("SHA1", RedisString("config/chbtc.key.private")[])
const chbtc_token = RedisString("config/chbtc.key.public")[]

function req_chbtc(url, params::String)
    sign = hexdigest("MD5", chbtc_key, params)
    time = ceil(Int, 1000Libc.time())
    url = "https://trade.chbtc.com/api$url?$params&sign=$sign&reqTime=$time"
    get(url) |> readstring |> JSON.parse
end

const huobi_key   = RedisString("config/huobi.key.private")[]
const huobi_token = RedisString("config/huobi.key.public")[]

function req_huobi_new(url, params::Dict)
    time = Dates.format(now(Dates.UTC), Dates.ISODateTimeFormat)

    params["AccessKeyId"] = huobi_token
    params["SignatureMethod"] = "HmacSHA256"
    params["SignatureVersion"] = "2"
    params["Timestamp"] = time[1:findfirst(time, '.')-1]

    str = join(map(x->"$(x[1])=$(URIParser.escape(x[2]))", sort(collect(params))), '&')
    sign = digest("SHA256", huobi_key, "GET\nbe.huobi.com\n/v1$url\n$str") |> base64encode |> URIParser.escape

    get("https://be.huobi.com/v1$url?$str&Signature=$sign") |> readstring |> JSON.parse
end

function req_huobi_old(url, params::Dict, extra::Dict=Dict())
    params["access_key"] = huobi_token
    params["created"] = floor(Int, Libc.time()) |> string

    str = join(map(x->"$(x[1])=$(URIParser.escape(x[2]))", sort(["secret_key"=>huobi_key, params...])), '&')
    params["sign"] = hexdigest("MD5", str)

    post("https://api.huobi.com/apiv3$url", data=merge(params, extra)) |> readstring |> JSON.parse
end

const okcoin_key   = RedisString("config/okcoin.key.private")[]
const okcoin_token = RedisString("config/okcoin.key.public")[]

function req_okcoin(url, params::Dict)
    params["api_key"] = okcoin_token

    str = join(map(x->"$(x[1])=$(x[2])", sort(collect(params))), '&')
    sign = hexdigest("MD5", str * "&secret_key=$okcoin_key") |> uppercase

    post("https://www.okcoin.cn/api/v1$url?$str&sign=$sign") |> readstring |> JSON.parse
end
