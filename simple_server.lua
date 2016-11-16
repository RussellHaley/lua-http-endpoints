local http_server = require "http.server"
local http_headers = require "http.headers"


local function ProcessIncoming(server, stream)
    local request_headers = assert(stream:get_headers())
    local request_method = request_headers:get ":method"

    print(string.format('[%s] "%s %s HTTP/%g"  "%s" "%s" ',
        os.date("%d/%b/%Y:%H:%M:%S %z"),
        request_headers:get(":method") or "",
        request_headers:get(":path") or "",
        stream.connection.version,
        request_headers:get("referer") or "-",
        request_headers:get("user-agent") or "-"
    ))

    local request_content_type = request_headers:get("content-type")
    local response_headers = http_headers.new()
    response_headers:append(":status", "200")
    response_headers:append("content-type", "text/plain")
    response_headers:append("content-type", request_content_type  or "text/html")
    assert(stream:write_headers(response_headers, request_method == "HEAD"))
    -- Send headers to client; end the stream immediately if this was a HEAD request
    if request_method == "HEAD" then return end;

    -- Send body, ending the stream
    local body = [[<html><head><head><body bgcolor="light blue">Hello From Timbuktu!</body></html>]]
    assert(stream:write_chunk(body, true))
end


local app_server = http_server.listen {
    host = "localhost";
    port = 8000;
    onstream = ProcessIncoming;
}

assert(app_server:listen())
do
    local interface, address, port = app_server:localname()

    print(string.format("Now listening on %s at port %d\n", address, port))
end
local ok, err, errno = app_server:loop()
if not ok then
    print(err, errno, "Http server process ended.", debug.traceback())
end

