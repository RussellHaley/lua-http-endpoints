--- lua_ws_client.
-- Created by IntelliJ IDEA.
-- Author: russellh
-- Date: 9/19/16


--local http_request = require "http.request"
--local headers, stream = assert(http_request.new_from_uri("http://example.com"):go())
--local body = assert(stream:get_body_as_string())
--if headers:get ":status" ~= "200" then
--    error(body)
--end
--print(body)


local cqueues = require "cqueues"
local websocket = require "http.websocket"
local json = require "dkjson"
local message1 = require "message1"
local instrumentation = require "instrumentation"
local configuration = require "configuration"
local file = require "file"

local i = instrumentation.new("client.conf")
local upd = i.UpdateInstrumentation

--local conf = configuration.new("/etc/rc.conf",true)
local conf = configuration.new("client.conf", false, false)
i.debug_file_path = conf.base_path .. "/" .. conf.debug_file_name

local InputWrapContinue = true
local Shutdown = false
local DEBUG = arg[1] or false

local function getUUID()
    local handle = io.popen("uuidgen")
    local val, lines = handle:read("*a")
    val = val:gsub("^%s*(.-)%s*$", "%1")
    return val
end

local function WriteError(err, errno, debugOut)
    local str = os.date("%Y-%m-%d_%H%M%S") .. " - Error No:" .. errno .. "- " .. err
    file.write(i.debug_file_path, str, 'a')
    if debugOut then
        print(str)
    end
end

local function InitRecieve(cq, ws)
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

local function InitStatusUpdate(cq, ws)
    cq:wrap(function()
        repeat
            local msg = message1.new()
            msg.uuid = getUUID()
            local items = i.ReadInstrumentation()
            for k, v in pairs(items) do
                msg.body[k] = v
            end

            str = json.encode(msg)
            local success, err, errno = ws:send(str)
            if not success then
                WriteError(err, errno, DEBUG)
            end
            cqueues.sleep(3)
        until Shutdown == true
    end)
end

local function toggleInputWrap(start, cq, ws)
    if start then
        cq:wrap(function()
            repeat
                io.stdout:write("Input> ")
                cqueues.poll({ pollfd = 0; events = "r" }) -- wait until data ready to read on stdin
                local data = io.stdin:read "*l" -- blockingly read a line. shouldn't block if tty is in line buffered mode.
                --                assert(ws:send(data)) -- echo it back?
            until not InputWrapContinue
        end)

    else
        InputWrapContinue = false
    end
end

local function InitDebugInput(cq)
    cq:wrap(function()
        repeat
            local bt = "board_temperature"
            local nv = "new_value_2"

            if i[bt] ~= nil then
                upd(bt, i[bt] + 152)
            else
                upd(bt, 152)
            end
            --print(bt.."out", i[bt])
            if i[nv] ~= nil then
                print("upd" .. nv)
                upd(nv, i[nv] + 3)
            else
                print(nv)
                upd(nv, 999)
            end

            cqueues.sleep(10)


        until Shutdown == true
    end)
end

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
    InitStatusUpdate(cq, ws)
    InitRecieve(cq, ws)
    local success, err
    repeat
        success, err = StartWraps(cq)
        if not success then
            WriteError(0, err, DEBUG)
        end

    until Shutdown == true
end


local function Shutdown()
    Shutdown = true
end


Begin()





