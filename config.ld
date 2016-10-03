project = "Example B"
title = "Example B"
description = [[Client/Server WebSocket applicaiton based in lua.]]
full_description = [[This is a client/server example based on lua-http and cqueues. The system is made up of two parts:
 1) A server implementation called nice_server that spawns a new thread for each connection. The system checks for the appropriate
 protocol and opens the correct connection
 2) A client. The client initiates a websocket connection and sends the instrumentation table once every three seconds. This
 was used simply as an example of reading from an LMDB database.
]]

all = true



