---
-- @copyright (c) 2016 Russell Haley
-- @license FreeBSD License. See License.txt


local strict = require "strict"
local cqueues = require "cqueues"
local notify = require "cqueues.notify"
local signal = require "cqueues.signal"
local auxlib = require "cqueues.auxlib"
local thread = require"cqueues.thread"
local assert = auxlib.assert -- cqueues doesn't yet do idiomatic error tuples

local progname = arg and arg[0] or "notify"

local function Notify(...)
    local msg = string.format(...)
    for ln, nl in msg:gmatch "([^\n]*)(\n?)" do
        if #ln > 0 or #nl > 0 then
            io.stderr:write(string.format("%s: %s\n", progname, ln))
        end
    end
end

local function parsepath(path)
    local isabs = path:match "^/" and true or false
    local name = {}

    for fname in path:gmatch "[^/]+" do
        name[#name + 1] = fname
    end

    return isabs, name
end

local function dirname(path)
    local isabs, name = parsepath(path)

    name[#name] = nil

    if isabs then
        return "/" .. table.concat(name, "/")
    elseif #name == 0 then
        return "."
    else
        return table.concat(name, "/")
    end
end

local function basename(path)
    local isabs, name = parsepath(path)
    local base = name[#name]

    if base then
        return base
    elseif isabs then
        return "/"
    else
        return "."
    end
end

local mainloop = cqueues.new()
local path = ... or "logtesting.log"

mainloop:wrap(function()
    Notify("watching %s", path)

    local nfy = assert(notify.opendir(dirname(path), notify.ALL))
    assert(nfy:add(basename(path)))

    for flags, name in nfy:changes() do
        -- ignore changes to containing directory
        if name == basename(path) then
            for flag in notify.flags(flags) do
                Notify("%s %s", name, notify[flag])
            end
        end
    end
end)


-- Waits on signals
mainloop:wrap(function()
    signal.block(signal.SIGINT, signal.SIGHUP)
    local signo = signal.listen(signal.SIGINT, signal.SIGHUP):wait()
    Notify("exiting on signal (%s)", signal.strsignal(signo))
    os.exit(0)
end)




--- Implement a dead-man switch in case a bug in our code causes the main
-- loop to stall.
--
-- ------------------------------------------------------------------------
mainloop:wrap(function()
    local thr, pipe = thread.start(function(pipe)
        local cqueues = require"cqueues"
        local sleep = cqueues.sleep
        local poll = cqueues.poll
        local loop = cqueues.new()

        loop:wrap(function()
            cqueues.sleep(10)

            -- try to drain socket so we don't get stale alive
            -- tokens on successive iterations.
            while pipe:recv(-32) do
                print("muchas Gracisas")
                poll(pipe, 10)
            end

            io.stderr:write"main thread unresponsive\n"

            os.exit(false)
        end)

        local ok, why = loop:loop()

        io.stderr:write(string.format("dead-man thread failed: %s\n", why or "unknown error"))

        os.exit(false)
    end)

    mainloop:wrap(function()
        while true do
            cqueues.sleep(5)
            assert(pipe:write"!\n")
            Notify("Ei, carumba!")
        end
    end)
end)


--cqueues.poll({pollfd = myfd; events = "p"})


for err in mainloop:errors() do
    Notify("%s", err)
    os.exit(1)
end