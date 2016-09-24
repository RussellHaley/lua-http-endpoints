--
-- Created by IntelliJ IDEA.
-- User: russellh
-- Date: 9/19/16
-- Time: 10:07 PM
-- To change this template use File | Settings | File Templates.
--
--local http_request = require "http.request"
--local headers, stream = assert(http_request.new_from_uri("http://example.com"):go())
--local body = assert(stream:get_body_as_string())
--if headers:get ":status" ~= "200" then
--    error(body)
--end
--print(body)

local websocket = require "http.websocket"
local ws = websocket.new_from_uri("ws://localhost:8000")
assert(ws:connect())
assert(ws:send([[authCommand {"Username":"Russell", "Password":"testing"}]]))
local data = assert(ws:receive())
print(data)
assert(ws:close())