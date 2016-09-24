local port = arg[1] or "8000"

local nice_server = require "nice_server"
local websocket = require "http.websocket"

local timeout = 2

local function reply(resp)

    local ws = websocket.new_from_stream(resp.headers, resp.stream)

    print("got here twice")
    assert(ws:accept())
    assert(ws:send("Welcome To LuaSocketServer"))
    local data = assert(ws:receive())
    print(data)

    local req_body = assert(resp.stream:get_body_as_string(timeout))
    local req_body_type = resp.request_headers:get "content-type"
    resp.headers:upsert(":status", "200")
    resp.headers:append("content-type", req_body_type or "text/plain")
    resp:set_body("I don't think so bub")
end

assert(nice_server.new {
    host = "localhost";
    port = port;
    reply = reply;
}:loop())

