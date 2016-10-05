--- Opens a websocket connection with
-- the server_url option specified in the client conf file.
-- @author Russell Haley, Created with IntelliJ IDEA.
-- @copyright 2016
-- @license BSD 2 Clause. See License.txt

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
local file = require "file"

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

--- Shutdown flag. Set to True to end all processes
local Shutdown = false
--- Debug flag. Enables Debugging output from the client.
DEBUG = arg[1] or false

local function Log(level, fmt, ...)
    local pkt = os.date("%Y-%m-%d_%H%M%S") .. "-" .. level .. ": " .. string.format(fmt, ...) .. "\n";
    if level:upper() == "ERROR" then
        pkt = debug.traceback(pkt, 2)
    end;
    if DEBUG then
        print(pkt)
    end
    return debug_file:write(pkt)
end

--- Writes errors to a file.
-- This needs serious work, or you should
-- just get a proper logger.
-- param: errno The error number provided by the exit call
-- param: err The error message provided by the exit call
-- param: debugOut true outputs the info to stdio
local function LogError(errno, err, ...)
    if not errno then errno = "na" end
    if not err then err = "na" end
    Log("ERROR", "%s", errno, err, ...)
end

--- Writes a line to the log. Appends Linefeed.
-- param: message - string for logging
local function LogInfo(message)
    Log("Info", "%s", message)
end



--- Get a UUID from the OS
-- return: Returns a system generated UUID
-- such as "4f1c1fbe-87a7-11e6-b146-0c54a518c15b"
-- usage: 4f1c1fbe-87a7-11e6-b146-0c54a518c15b
local function GetUUID()
    local handle = io.popen("uuidgen")
    local val, lines
    if handle then
        val, lines = handle:read("*a")
        --Don't remembe what this does, I think
        -- it strips whitespace?
        val = val:gsub("^%s*(.-)%s*$", "%1")
    else
        WriteError(0, "Failed to generate UUID");
    end
    return val
end

--- InitReceive. Starts the CQ wrap that listens on the websocket
-- param: cq - The cqueue to which we will add the routine
-- param: ws - The websocket reference
local function Receive(ws)
    repeat
        local response, err, errno = ws:receive() -- does this return an error message if it fails?
        if not response then
            LogError(err, errno)
            ws:close()
            Shutdown = true
        else
            print(response)
        end
    until not response or Shutdown == true
end

--- InitStatusUpdate. Starts the cqueue wrap for sending
-- status updates to the server.
-- param: cq - The cqueue to which we will add the routine
-- param: ws - The websocket reference
-- param: sleepPeriod - The periodicity of the status update
local function StatusUpdate(ws, sleepPeriod)
    repeat
        local msg = message1.new()
        msg.uuid = GetUUID()
        local items = i.ReadInstrumentation()
        for k, v in pairs(items) do
            msg.body[k] = v
        end

        str = json.encode(msg)
        local success, err, errno = ws:send(str)
        if not success then
            LogError(err, errno)
        end
        --This value should come from the config file.
        cqueues.sleep(sleepPeriod)
    until Shutdown == true
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
        print(data)
        if data:upper() == "SHUTDOWN" then StopServices() end;
    until Shutdown == true
end

--- StartWraps. Start all the wraps. This give us ~some logging
-- if the step fails.
-- param:cq - The cqueue to start the routines on.
local function Initialize(cq, ws)
    cq:wrap(Receive, ws)
    cq:wrap(StdioInput)
    cq:wrap(DebugInput)
    cq:wrap(StatusUpdate, ws, conf.status_period)
    return true
end

--- Starts all processing in the applicaiton.
local function Begin()
    debug_file = io.open(i.debug_file_path, 'a')

    LogInfo("Starting client service on " .. os.date("%b %d, %Y %X"))

    local cq = cqueues.new()
    local ws = websocket.new_from_uri("ws://" .. conf.server_url .. ":" .. conf.server_port)
    local ws_ok, err, errno = ws:connect()
    if ws_ok then
        local init_ok = Initialize(cq, ws)

        if init_ok then
            repeat
                local cq_ok, msg, errno = cq:step()
                if cq_ok then
                    LogInfo("Step")
                else

                    LogInfo("The main cqueue failed to step.")
                    LogError(errno, msg)
                end
            until Shutdown == true or cq:empty()
            ws:close()
        else
            LogError(99, "Failed to initialize the sub routines for the application.")
        end
    else
    end
end



Begin()

--local http_request = require "http.request"
--local headers, stream = assert(http_request.new_from_uri("http://example.com"):go())
--local body = assert(stream:get_body_as_string())
--if headers:get ":status" ~= "200" then
--    error(body)
--end
--print(body)


