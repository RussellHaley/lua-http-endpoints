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
local message1 = require "message1"
local cqueues = require "cqueues"
local ws = websocket.new_from_uri("ws://localhost:8000")

assert(ws:connect())
assert(ws:send([[authCommand {"Username":"Russell", "Password":"testing"}]]))

local data
local response

local msg = message1.new()

local stop = false
recieve_q = cqueues.new()
recieve_q:wrap(
    function()
        while 1 do
            print("got here")
            local response = ws:recieve()
            print(response)
        end
    end)

recieve_q:loop()

--asset(ws:send("hello from mars"))
while stop ~= true do
    io.write("input> ")
    data = io.read("*line")
    print(data)
    if data:upper() == "STOP" then
        stop = true
    end
    ws:send(data)

end

assert(ws:close())
