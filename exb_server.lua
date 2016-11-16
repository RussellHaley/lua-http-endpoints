--- Remote Client Server utilizing lua-http library
-- @copyright (c) 2016 Russell Haley
-- @license FreeBSD License. See License.txt

local cqueues = require "cqueues"
local signal = require "cqueues.signal"
local http_server = require "http.server"
local http_headers = require "http.headers"
local websocket = require "http.websocket"
local dkjson = require "dkjson"
local serpent = require "serpent"
local configuration = require "configuration"
local conf = configuration.new([[exb_server.conf]])
local mbase = require "message_base"
local watchdog = require "watchdog"
local rolling_logger = require "logging.rolling_file"

local logger = rolling_logger(conf.base_path .. "/" .. conf.debug_file_name, conf.file_roll_size or 1024*1024*10, conf.max_log_files or 31)
if not logger then
    print("logger failed")
    os.exit(0)
end

local connection_log = rolling_logger(conf.base_path .. "/" .. conf.debug_file_name, conf.file_roll_size or 1024*1024*10, conf.max_log_files or 31)

local DEBUG = arg[1] or false

local sessions = {}

--- Debugging tool
local function PrintTable(t)
    for k, v in pairs(t) do
        print(k, v)
    end
end

----- Base logging function. If the file is not
---- open, it opens it. Writes to file but does
---- not close it.
--local function Log(level, fmt, ...)
--    if not debug_file then
--        debug_file = io.open(conf.base_path .. "/" .. conf.debug_file_name, 'a')
--    end
--
--    local msg = os.date("%Y-%m-%d %H:%M:%S") .. " - " .. level .. ": "
--    for _, v in ipairs { ... } do
--        msg = msg .. " " .. string.format(fmt, v);
--    end
--    msg = msg .. "\n"
--    if DEBUG then
--        print(msg)
--    end
--    debug_file:write(msg)
--    return debug_file:flush()
--end


----- Writes errors to a file.
---- param: errno The error number provided by the exit call
---- param: err The error message provided by the exit call
---- param: debugOut true outputs the info to stdio
--local function logger:error(err, errno, ...)
--    if not errno then errno = "" end
--    if not err then err = "" end
--    Log("Error", "%s", err, errno, ...)
--end
--
----- Writes a  non-error line to the log. Appends Linefeed.
---- param: message - string for logging
--local function logger:info(message)
--    Log("info", "%s", message)
-- end


--- Prints nested tables. Another debugging tool
local function pt(t)
    local str = ""
    for k, v in pairs(t) do
        if type(v) == "table" then
            str = str .. "----------" .. k .. "------------"
            str = str.. pt(v)
        else
            str = str .. k .. ": " .. v .. "\n"
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
        logger:error(0, "Failed to generate UUID");
    end
    return val
end


local function ProcessWebsocketMessage(t, msg)

    if msg.type then

        local type = msg.type:upper()

        if type == "STATUS" then
            t.last_status = os.date()
            local bt = tonumber(msg.body.board_temperature)
            if bt and bt > 158 then
                print("too hot")
                local reply = mbase.New(msg)
                reply.body.response = "Too Damn Hot!"

                t.websocket:send(dkjson.encode(reply))
                logger:info(pt(reply))
            end

            --Log status for each client
        elseif type == "AUTH" then

        elseif type == "DATADUMP" then

        elseif type == "UNIT-RESPONSE" then
        else
            logger:info("Type=" .. msg.type)
            logger:info(pt(msg))
        end
    end
end

--- ProcessRequest is where we process the request from the client.
-- The system upgrades to a websocket if the ws or wss protocols are used.
-- @param server ?
-- @param An open stream to the client. Raw socket abstraction?
local function ProcessRequest(server, stream)

    local request_headers = assert(stream:get_headers())
    local request_method = request_headers:get ":method"


    --how do I get the client url and mac?
    connection_log:info(string.format('[%s] "%s %s HTTP/%g"  "%s" "%s" ',
        os.date("%d/%b/%Y:%H:%M:%S %z"),
        request_headers:get(":method") or "",
        request_headers:get(":path") or "",
        stream.connection.version,
        request_headers:get("referer") or "-",
        request_headers:get("user-agent") or "-"
        ))


    local id = GetUUID()

    local ws = websocket.new_from_stream(stream, request_headers)
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
                        logger:info(serpent.block(msg))
                    end
                    ProcessWebsocketMessage(t, msg)
                else
                    logger:info("message could not be parsed")
                    logger:info(pos, err)
                end
            else
                --Add valid reason codes for the data to be nil?
                if errno == 1 then

                else
                    logger:error(err, errno, "Recieve Failed")
                end
            end

        until not data
        logger:info("removed " .. id)
        sessions[id] = nil
    else
        --standard HTTP request. Need to still do something with it.
        local request_content_type = request_headers:get("content-type")
        local req_body = assert(stream:get_body_as_string(timeout))
        logger:info(req_body)
        local response_headers = http_headers.new()
        response_headers:append(":status", "200")
        response_headers:append("content-type", "text/plain")
        response_headers:append("content-type", request_content_type  or "text/html")

        assert(stream:write_headers(response_headers, request_method == "HEAD"))
        -- Send headers to client; end the stream immediately if this was a HEAD request
        if request_method == "HEAD" then return end;
        -- Send body, ending the stream
        local body = [[<html><head><head><body bgcolor="light blue">This server doesn't like http right now. Please use a websocket</body></html>]]
        --resp:set_body([[<html><head><head><body bgcolor="light blue">This server doesn't like http right now. Please use a websocket</body></html>]])
        assert(stream:write_chunk(body, true))
    end
end

--- Polls the table of "Client" objects that contain a reference
-- to the underlying websocket so you can push messages
local function PollClients()
    while 1 do
        for _, v in pairs(sessions) do
            v.websocket:send("yeeha!")
            --v.websocket:ping()
            logger:info(string.format("Ping - %s: %s", v.session_id, v.session_start))
        end
        cqueues.sleep(3)
    end
end

--- Waits on signals. Useful if the server goes dead.
local function SignalsRoutine()
    signal.block(signal.SIGINT, signal.SIGHUP)
    local signo = signal.listen(signal.SIGINT, signal.SIGHUP):wait()
    logger:info(string.format("exiting on signal (%s)", signal.strsignal(signo)))
    os.exit(0)
end

local app_server = http_server.listen {
    host = conf.host;
    port = conf.port;
    onstream = ProcessRequest;
}
local main = cqueues.new()
--local doggy = watchdog.new(main, logger)
--
--main:wrap(doggy.run)
--main:wrap(doggy.signals)

main:wrap(function()
    -- Manually call :listen() so that we are bound before calling :localname()
    assert(app_server:listen())
    do
        print(app_server:localname())
        logger:info(string.format("Now listening on port %d\n", conf.port))
    end
    local cq_ok, err, errno = app_server:loop()
    if not cq_ok then
        logger:error(err, errno, "Http server process ended.", debug.traceback())
    end
end)

for err in main:errors() do
    print(err)
    logger:error("%s", err)
    os.exit(1)
end



