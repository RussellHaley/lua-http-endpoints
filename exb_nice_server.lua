--- This is the server script that runs the websocket/http server
-- @author Russell Haley, Created with IntelliJ IDEA.
-- @copyright 2016
-- @license BSD 2 Clause. See License.txt

local cqueues = require "cqueues"
local nice_server = require "nice_server"
local websocket = require "http.websocket"
local dkjson = require "dkjson"
local serpent = require "serpent"

local configuration = require "configuration"

local conf = configuration.new([[exb_server.conf]])

local debug_file
local DEBUG = arg[1] or false

local sessions = {}

function PrintTable(t)
    for k, v in pairs(t) do
        print(k, v)
    end
end

local function Log(level, fmt, ...)
    if not debug_file then
        debug_file = io.open(conf.base_path .. "/" .. conf.debug_file_name, 'a')
    end

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
    for k, v in pairs(t) do
        if type(v) == "table" then
            --print(k,"table")
            pt(v)
        else
            print(k, v)
        end
    end
end

--local timeout = 2

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


local function ProcessMessage(msg)
    print("msg received " .. os.date())
    if msg.type then
        local type = msg.type:upper()
        if type == "STATUS" then
            --pt(msg)
            --Log status for each client
        elseif type == "AUTH" then

        elseif type == "DATADUMP" then

        elseif type == "UNIT-RESPONSE" then
        else
            print("Type=" .. msg.type)
            pt(msg)
        end
    end
end

--- Reply is where we process the request from the client.
-- The system upgrades to a websocket if the ws or wss protocols are used.
-- @param resp A table with response meta data retrieved from the request.
-- This would typically be used in an http response.
local function reply(resp)


    for k, v in pairs(resp.request_headers) do
        print(k, v)
    end

    local id = GetUUID()



    local ws = websocket.new_from_stream(resp.stream, resp.request_headers)
    if ws then
        local t = {}
        t.session_id = id
        t.session_start = os.date()
        t.websocket = ws
        sessions[id] = t

        assert(ws:accept())
        assert(ws:send("Welcome To exb Server"))
        assert(ws:send("Your client id is " .. t.session_id))

        --Send an Authenticate required message
        repeat
            local data, err, errno = ws:receive()
            if data then
                local msg, pos, err = dkjson.decode(data, 1, nil)
                if msg then
                    if DEBUG then
                        print(serpent.dump(msg))
                    end
                    ProcessMessage(msg)
                else
                    LogInfo("message could not be parsed")
                    LogInfo(pos, err)
                end
            else
                --Add valid reason codes for the data to be nil?
                if errno == 1 then

                else
                    LogError(err, errno, "Recieve Failed")
                end
            end

        until not data
        LogInfo("removed " .. id)
        sessions[id] = nil
    else
        --standard HTTP request. Need to still do something with it.
        local req_body = assert(resp.stream:get_body_as_string(timeout))
        LogInfo(req_body)
        resp.headers:upsert(":status", "200")
        resp.headers:append("content-type", req_body_type or "text/html")
        resp:set_body([[<html><head><head><body bgcolor="light blue">This server doesn't like http right now. Please use a websocket</body></html>]])
    end
end

cq = cqueues.new()

cq:wrap(function()
    while 1 do
        for k, v in pairs(sessions) do
            v.websocket:send("yeeha!")
            --v.websocket:ping()
            print(v.session_id, v.session_start)
        end
        cqueues.sleep(3)
    end
end)
cq:wrap(function()

    assert(nice_server.new {
        host = conf.host;
        port = conf.port;
        reply = reply;
    }:loop())
end)

assert(cq:loop())

if debug_file then
    debug_file:close()
end

