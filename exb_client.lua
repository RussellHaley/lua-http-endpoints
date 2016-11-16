--- Opens a websocket connection with
-- the server_url option specified in the client conf file.
-- @copyright (c) 2016 Russell Haley
-- @license FreeBSD License. See License.txt

--- The cqueue library
local cqueues = require "cqueues"
--- lua-http websockets
local websocket = require "http.websocket"
--- json parser for converting tables to json
local json = require "dkjson"
--- a base message. I'm not very good at
-- Prototyping in Lua yet
local message1 = require "message_base"
--- See: instrumentation.lua
local instrumentation = require "instrumentation"
--- See: configuration.lua
local configuration = require "configuration"
--- A little library for file manipulation,
-- familiar patterns for a C# developer.
--local file = require "file"

--Lua only serializer package.
--local serialize = require "ser"
--Used to generate Cyclicle Redundancy Checksum
--local CRC = require 'crc32lua'

local i = instrumentation.new("exb_client.conf")
local upd = i.UpdateInstrumentation

--local conf = configuration.new("/etc/rc.conf",true)
local conf = configuration.new("exb_client.conf", false, false)
i.debug_file_path = conf.base_path .. "/" .. conf.debug_file_name
local debug_file;

local cq;

local ws;

--- Shutdown flag. Set to True to end all processes
local Shutdown = false
--- Debug flag. Enables Debugging output from the client.
DEBUG = arg[1] or false

local function Log(level, fmt, ...)
    local msg = os.date("%Y-%m-%d_%H%M%S") .. " - " .. level .. ": "
    for _, v in ipairs { ... } do
        msg = msg .. " " .. string.format(fmt, v);
    end
    msg = msg .. "\n"
    if DEBUG then
        print(msg)
    end
    return debug_file:write(msg)
end

--- Writes errors to a file.
-- This needs serious work, or you should
-- just get a proper logger.
-- param: errno The error number provided by the exit call
-- param: err The error message provided by the exit call
-- param: debugOut true outputs the info to stdio
local function LogError(err, errno, ...)
    if not errno then errno = "" end
    if not err then err = "" end
    Log("Error", "%s", err, errno, ...)
end

--- Writes a line to the log. Appends Linefeed.
-- param: message - string for logging
local function LogInfo(message)
    Log("Info", "%s", message)
end

local function pt(t)
    local str = ""
    for k, v in pairs(t) do
        if type(v) == "table" then
            str = str.."----------"..k.."------------"
            pt(v)
        else
            if DEBUG then
                print(k, v)
            end
            str=str..k..": "..v.."\n"
        end
    end
    return str
end

--- Get a UUID from the OS
-- return: Returns a system generated UUID
-- such as "4f1c1fbe-87a7-11e6-b146-0c54a518c15b"
-- usage: 4f1c1fbe-87a7-11e6-b146-0c54a518c15b
local function GetUUID()
    local handle = io.popen("uuidgen")
    local val, lines
    if handle then
        val = handle:read("*a")
        --Don't remembe what this does, I think
        -- it strips whitespace?
        val = val:gsub("^%s*(.-)%s*$", "%1")
        handle:close()
    else
        LogError(0, "Failed to generate UUID");
    end
    return val
end

local function ProcessReceived(data)
    local msg, pos, err = dkjson.decode(data, 1, nil)
    if msg then

        if DEBUG then
            print(pt(msg))
        end
        LogInfo(msg.body)
    else
        LogInfo("message could not be parsed")
        LogInfo(pos, err)
    end

end

--- InitReceive. Starts the CQ wrap that listens on the websocket
-- param: cq - The cqueue to which we will add the routine
-- param: ws - The websocket reference
local function Receive()
    repeat
        print("receiving...")
        --need to check the websocket first and connect it if it's down.
        local response, err, errno = ws:receive() -- does this return an error message if it fails?
        if not response then
            LogError(err, errno, "Recieve Failed. ", debug.traceback())
            LogInfo("waiting...")
            error("Receive Failed")
        else
            print("response: " .. response .. " sizeof: " .. #response)
        end
    until Shutdown == true
end

--- InitStatusUpdate. Starts the cqueue wrap for sending
-- status updates to the server.
-- param: cq - The cqueue to which we will add the routine
-- param: ws - The websocket reference
-- param: sleepPeriod - The periodicity of the status update
local function StatusUpdate(sleepPeriod)
    repeat
        --if not, go back to sleep
        local msg = message1.New()
        msg.uuid = GetUUID()
        msg.type = "status"
        msg.sequence = 1
        local items = i.ReadInstrumentation()
        for k, v in pairs(items) do
            msg.body[k] = v
        end

        local str = json.encode(msg)
        local ok, err, errno = ws:send(str)
        if not ok then
            LogInfo("send failed.")
            LogError(err, errno, "Send Failed. ", debug.traceback())
            error("Send Failed")
        else
            cqueues.sleep(sleepPeriod)
        end
    until Shutdown == true or not ok
end



--- InitDebugInput. Creates sample data for testing.
-- param: cq - The cqueue to which we will add the routine
local function DebugInput()
    repeat
        local bt = "board_temperature"
        local nv = "new_value_2"

        local bt_val
        local nv_val

        --        local i
        --        i = 6

        bt_val = 152
        nv_val = 999

        if i[bt] ~= nil then
            bt_val = i[bt] + 152
        end
        upd(bt, bt_val)

        if i[nv] ~= nil then
            nv_val = i[nv] + 3
        end

        upd(nv, nv_val)

        if DEBUG then
            print(nv, nv_val)
            print(bt, bt_val)
            print(Shutdown)
        end
        cqueues.sleep(10)
    until Shutdown == true
end

local function StopServices()
    Shutdown = true
    -- Can I use a condition here instead?
    --The condition can be used to shut down
    -- the ws:receive(cond?) and checked before the
    -- if not condition(?) then send() end;
    ws:close()
    LogInfo("System shutdown initiated.")
end


--- InitStdioInput. A cq wrap for input from stdio. It's
-- purpose is for manual inupt and debugging.
-- param: cq - The cqueue to which we will add the routine
local function StdioInput()
    repeat
        io.stdout:write("Input> ")
        cqueues.poll({ pollfd = 0; events = "r" }) -- wait until data ready to read on stdin
        local data = io.stdin:read "*l" -- blockingly read a line. shouldn't block if tty is in line buffered mode.
        if data:upper() == "SHUTDOWN" then StopServices() end;
    until Shutdown == true
end


local function Run()

    debug_file = io.open(i.debug_file_path, 'a')

    LogInfo("Starting client service on " .. os.date("%b %d, %Y %X"))

    cq = cqueues.new()



    cq:wrap(StdioInput)
    cq:wrap(DebugInput)

    cq:wrap(StatusUpdate, conf.status_period)

    repeat
        ws = websocket.new_from_uri("ws://" .. conf.server_url .. ":" .. conf.server_port)
        local ws_ok, err, errno = ws:connect()
        if ws_ok then
--            print(ws:localname())
--            print(ws:peername())
            cq:wrap(Receive)
            LogInfo("Connected to " .. conf.server_url .. ":" .. conf.server_port)
            local cq_ok, err, errno = cq:loop()
            if not cq_ok then
                LogError(err, errno, "Jumped the loop.", debug.traceback())
            end
            --If this falls out, check for errors before looping again
        else
            LogError(err, errno)
            LogInfo("Failed to connect. Sleeping for " .. conf.connect_sleep)
            cqueues.sleep(conf.connect_sleep)
        end

    until Shutdown == true

    --[[repeat
        local cq_ok, msg, errno = cq:step()
        if cq_ok then
            LogInfo("Step")
        else

            LogInfo("The main cqueue failed to step.")
            LogError(errno, msg)
        end
    until Shutdown == true or cq:empty()
    ws:close()]]

    --[[To get the error from step() --
    -- local cq_ok, msg, errno, thd = cq:step(); if not cq_ok then print(debug.traceback(thd, msg)) end
    -- ]]
end


Run()


--local http_request = require "http.request"
--local headers, stream = assert(http_request.new_from_uri("http://example.com"):go())
--local body = assert(stream:get_body_as_string())
--if headers:get ":status" ~= "200" then
--    error(body)
--end
--print(body)


