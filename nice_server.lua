local cqueues = require "cqueues"
local cc = require "cqueues.condition"
local ce = require "cqueues.errno"
local new_headers = require "http.headers".new
local server = require "http.server"
local version = require "http.version"
local http_util = require "http.util"

local websocket = require "http.websocket"

--local zlib = require "http.zlib"

local default_server = string.format("%s/%s", version.name, version.version)

local error_text = [[
<html>
<head>
<title>503 Internal Server Error</title>
</head>
<body>
An internal server error occured.
</body>
</html>
]]

local response_methods = {}
local response_mt = {
    __index = response_methods;
    __name = nil;
}

local function new_response(request_headers, stream)
    local headers = new_headers();
    -- Give some defaults
    headers:append(":status", "503")
    headers:append("server", default_server)
    headers:append("date", http_util.imf_date())
    return setmetatable({
        request_headers = request_headers;
        stream = stream;
        -- Record peername upfront, as the client might disconnect before request is completed
        peername = select(2, stream:peername());

        headers = headers;
        body = nil;
    }, response_mt)
end

function response_methods:combined_log()
    -- Log in "Combined Log Format"
    -- https://httpd.apache.org/docs/2.2/logs.html#combined
    return string.format('%s - - [%s] "%s %s HTTP/%g" %s %d "%s" "%s"',
        self.peername or "-",
        os.date("%d/%b/%Y:%H:%M:%S %z"),
        self.request_headers:get(":method") or "",
        self.request_headers:get(":path") or "",
        self.stream.connection.version,
        self.headers:get(":status") or "",
        self.stream.stats_sent,
        self.request_headers:get("referer") or "-",
        self.request_headers:get("user-agent") or "-")
end

function response_methods:set_body(body)
    self.body = body
    local length
    if type(self.body) == "string" then
        length = #body
    end
    if length then
        self.headers:upsert("content-length", string.format("%d", #body))
    end
end

function response_methods:set_503()
    local headers = new_headers()
    headers:append(":status", "503")
    headers:append("server", default_server)
    headers:append("date", http_util.imf_date())
    self.headers = headers
    headers:append("content-type", "text/html")
    self:set_body(error_text)
end

function response_methods:enable_compression()
    if self.headers:has("content-encoding") then
        return false
    end
    local deflater-- = zlib.deflate()
    --local new_body = deflater(self.body, true)
    local new_body = self.body
    self.headers:append("content-encoding", "gzip")
    self.body = new_body
    return true
end

local function default_onerror(...)
    io.stderr:write(string.format(...), "\n\n")
end
local function default_log(response)
    io.stderr:write(response:combined_log(), "\n")
end

local function new(options)
    local reply = assert(options.reply)
    local onerror = options.onerror or default_onerror
    local log = options.log or default_log
    local myserver = server.listen(options)

    local main_cq = cqueues.new()
    main_cq:wrap(function()
        local clients_cq = cqueues.new()
        -- create a thread that waits forever so :loop doesn't return
        local cond = cc.new()
        clients_cq:wrap(function()
            cond:wait()
        end)
        cqueues.running():wrap(function()
            while true do
                local _, err, _, thd = clients_cq:loop()
                if thd == nil then -- non-thread specific error; something is terribly wrong
                error(err)
                end
                onerror("client thread error: %s", debug.traceback(thd, err))
            end
        end)
        assert(myserver:run(function(stream)
            local req_headers, err, errno = stream:get_headers()
            if req_headers == nil then
                -- connection hit EOF before headers arrived
                stream:shutdown()
                if err ~= ce.EPIPE and errno ~= ce.ECONNRESET then
                    onerror("header error: %s", tostring(err))
                end
                return
            end

            local resp = new_response(req_headers, stream)

            local ok, err2 = pcall(reply, resp) -- only works in 5.2+

            if stream.state ~= "closed" and stream.state ~= "half closed (local)" then
                if not ok then
                    resp:set_503()
                end
                local send_body = resp.body and req_headers:get ":method" ~= "HEAD"
                stream:write_headers(resp.headers, not send_body)
                if send_body then
                    stream:write_chunk(resp.body, true)
                end
            end
            stream:shutdown()
            if not ok then
                onerror("stream error: %s", tostring(err2))
            end
            log(resp)
        end, clients_cq))
    end)
    return main_cq
end

return {
    new = new;
}