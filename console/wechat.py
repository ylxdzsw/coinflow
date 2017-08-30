import itchat
import redis
import time

@itchat.msg_register(itchat.content.TEXT, isFriendChat=True, isGroupChat=True, isMpChat=True)
def echo(msg):
    if "alive" in msg['Text']:
        return "I'm still alive"

itchat.auto_login()
itchat.run(blockThread=False)

room = itchat.search_chatrooms("coin")[0]["UserName"]

db = redis.StrictRedis(db=1)

channel = db.pubsub()
channel.subscribe(**{'channel/wechat.msg': lambda x: itchat.send_msg(x["data"].decode(), room)})

channel.run_in_thread(sleep_time=0.001)

while True:
    db.set("status/wechat.alive", '', 25)
    time.sleep(20)
