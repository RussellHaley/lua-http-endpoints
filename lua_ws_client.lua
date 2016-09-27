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

local somevar = false
local cqueues = require "cqueues"
local websocket = require "http.websocket"
local serpent = require "serpent"

local message1 = require "message1"
local instrumentation = require "instrumentation"

local cq = cqueues.new()

local i = instrumentation.new("lua_ws_client")

i.Newvalue = 100
i.new_value_2 = 999



local ws = websocket.new_from_uri("ws://localhost:8000")
assert(ws:connect())

cq:wrap(function()
    repeat
        local response = ws:receive()
        print(response)
    until not response or response:upper() == "QUIT"
end)


local shutdown = false
cq:wrap(function()
    repeat
        io.stdout:write("Input> ")
        cqueues.poll({pollfd=0; events="r"}) -- wait until data ready to read on stdin
        local data = io.stdin:read"*l" -- blockingly read a line. shouldn't block if tty is in line buffered mode.
        if data == nil or data:upper() == "QUIT" then
            shutdown = true
            ws:close()
            break
        end
        assert(ws:send(data)) -- echo it back?
    until shutdown ~= false
    --cleanup here
end)

cq:wrap(function()
    repeat

        local msg = message1.new()
        msg.uuid = getUUID()
        str = serpent.dump(msg)
        assert(ws:send(str))
        print(str)
        cqueues.sleep(3)
    until shutdown ~= false
end)

local function getUUID()
    local handle = io.popen("uuidgen")
    local val, lines = handle:read("*a")
    val = val:gsub("^%s*(.-)%s*$", "%1")
    return val
end

repeat assert(cq:step())

until somevar or cq:empty()



