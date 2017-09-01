using JSON
using Restful
using Restful: json
using HttpServer
using RedisAlchemy
using OhMyJulia
using JsonBuilder

const db = RedisConnectionPool(db=1)
set_default_redis_connection(db)

function candletime(x=floor(Int, time()))
    x > 10000000000 ? x ÷ 300000 - 5000000 :
    x < 100000000   ? x : x ÷ 300 - 5000000
end

@resource root let
    :mixin => defaultmixin
end

for component in readdir(rel"components")
    include("components/$component/main.jl")
end

@async run(Server(root), host=ip"0.0.0.0", port=2333)

isinteractive() || wait()
