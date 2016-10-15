# lua-http-endpoints

This is a non-trivial (less trivial?) example of using lua-http and cqueues to create a http and websocket based application that can be used for remote communications.

* lua_ws_client.lua - client code that sends periodic status updates
* nice_server.lua - Un-modified from Daurnimators example http server. Thanks again Daurnimator.
* envb_socket_server.lua - The server side application logic that processes incoming requests

![Powered By Lua 5.3](https://www.lua.org/images/powered-by-lua.gif)
