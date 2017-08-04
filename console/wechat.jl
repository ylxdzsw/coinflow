using RedisAlchemy
using OhMyJulia
using PyCall
using JSON
using Fire

@pyimport itchat

const conn = RedisConnectionPool(db=1)
const msgq = RedisCondition{String}(conn, "channel/wechat.msg")

alive = true

@schedule while true # heartbeating
    alive && exec(conn, "set", "status/wechat.alive", "", "EX", "25")
    sleep(2)
end

@schedule while true # forward msg
    sleep(1)
end

@main function main()
    itchat.auto_login(hotReload=true, statusStorageDir="/tmp/piggy.wechat.pkl")
    itchat.run(blockThread=false)
    alive = true

    subscriber = itchat.search_chatrooms("coineering")[]["UserName"]

    while true
        msg = wait(msgq)
        itchat.send_msg(msg, subscriber)
    end
end
