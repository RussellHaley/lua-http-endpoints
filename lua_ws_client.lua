--- script: lua_ws_client.lua

--local http_request = require "http.request"
--local headers, stream = assert(http_request.new_from_uri("http://example.com"):go())
--local body = assert(stream:get_body_as_string())
--if headers:get ":status" ~= "200" then
--    error(body)
--end
--print(body)

--- The cqueue library
local cqueues = require "cqueues"
--- lua-http websockets
local websocket = require "http.websocket"
--- json parser for converting tables to json
local json = require "dkjson"
--- a base message. I'm not very good at
-- Prototyping in Lua yet
local message1 = require "message1"
--- See: instrumentation.lua
local instrumentation = require "instrumentation"
--- See: configuration.lua
local configuration = require "configuration"
--- A little library for file manipulation,
-- familiar patterns for a C# developer.
local file = require "file"

local i = instrumentation.new("client.conf")
local upd = i.UpdateInstrumentation

--local conf = configuration.new("/etc/rc.conf",true)
local conf = configuration.new("client.conf", false, false)
i.debug_file_path = conf.base_path .. "/" .. conf.debug_file_name

--- Shutdown flag. Set to True to end all processes
local Shutdown = false
--- Debug flag. Enables Debugging output from the client.
DEBUG = arg[1] or false



--- Writes errors to a file.
-- This needs serious work, or you should
-- just get a proper logger.
-- param: errno The error number provided by the exit call
-- param: err The error message provided by the exit call
-- param: debugOut true outputs the info to stdio
local function WriteError(errno, err, debugOut)
    if not errno then errno = "na" end
    if not err then err = "na" end
    local str = os.date("%Y-%m-%d_%H%M%S") .. " - Error:" .. errno .. "- " .. err .. "\n"
    file.write(i.debug_file_path, str, 'a')
    if debugOut then
        print(str)
    end
end

--- Writes a line to the log. Appends Linefeed.
-- param: message - string for logging
local function WriteLog(message)
    local str = os.date("%Y-%m-%d_%H%M%S") .. message .. "\n"
    file.write(i.debug_file_path, str, 'a')
    if DEBUG then
        print(str)
    end
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
local function InitReceive(cq, ws)
    cq:wrap(function()
        repeat
            local response, err, errno = ws:receive() -- does this return an error message if it fails?
            if not response then
                WriteError(err, errno, DEBUG)
                ws:close()
                Shutdown = true
            else
                print(response)
            end
        until not response or response:upper() == "QUIT" or Shutdown == true
    end)
end

--- InitStatusUpdate. Starts the cqueue wrap for sending
-- status updates to the server.
-- param: cq - The cqueue to which we will add the routine
-- param: ws - The websocket reference
-- param: sleepPeriod - The periodicity of the status update
local function InitStatusUpdate(cq, ws, sleepPeriod)
    cq:wrap(function()
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
                WriteError(err, errno, DEBUG)
            end
            --This value should come from the config file.
            cqueues.sleep(sleepPeriod)
        until Shutdown == true
    end)
end

--- InitStdioInput. A cq wrap for input from stdio. It's
-- purpose is for manual inupt and debugging.
-- param: cq - The cqueue to which we will add the routine
local function InitStdioInput(cq)
        cq:wrap(function()
            repeat
                io.stdout:write("Input> ")
                cqueues.poll({ pollfd = 0; events = "r" }) -- wait until data ready to read on stdin
                local data = io.stdin:read "*l" -- blockingly read a line. shouldn't block if tty is in line buffered mode.
                --                assert(ws:send(data)) -- echo it back?
            until Shutdown == true
        end)
end

--- InitDebugInput. Creates sample data for testing.
-- param: cq - The cqueue to which we will add the routine
local function InitDebugInput(cq)
    cq:wrap(function()
        repeat
            local bt = "board_temperature"
            local nv = "new_value_2"

            local bt_val
            local nv_val

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
            end
            cqueues.sleep(10)
        until Shutdown == true
    end)
end

--- StartWraps. Start all the wraps. This give us ~some logging
-- if the step fails.
-- param:cq - The cqueue to start the routines on.
local function StartWraps(cq)
    local success, message
    repeat
        success, message = cq:step()
    until not success or cq:empty()
    return success, message
end

local function Begin()
    WriteError(0, "Begin")
    local cq = cqueues.new()
    local ws = websocket.new_from_uri("ws://" .. conf.server_url .. ":" .. conf.server_port)
    assert(ws:connect())

    InitDebugInput(cq, ws)
    InitStatusUpdate(cq, ws, conf.status_period)
    InitReceive(cq, ws)
    local success, err
    repeat
        success, err = StartWraps(cq)
        if not success then
            WriteLog("The main cqueue failed to step.")
            WriteError(0, err, DEBUG)
        end
    until Shutdown == true
end


local function Shutdown()
    Shutdown = true
end


Begin()





