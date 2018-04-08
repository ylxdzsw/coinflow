every micro services should:
- use thier name as id
- send heartbeat to redis every 5 sec with pid, expires after 12 sec
- write thier own logs with all data and info: data, debug, info, warn, notif
- write data to redis followed by an notification
- report important log to redis
- should be stateless: can restart any time

type of micro services:
- sensor: listen to depth
- recorder: save all data
- logger: save info, warn and notif
- notifier: notify notif

redis record types:
- market: current market state
    - order_price: live for 15s
- log: log queue of each service
- data: data queue of each type of data
- notif: notification queue
- status: status of micro services
- channel: one-time notification, mostly when data update
