---
-- @author russellh
-- @Copyright (C) 2016 Russell Haley
-- @license FreeBSD License. See License.txt

local strict = require "strict"
local cqueues = require "cqueues"
local notify = require "cqueues.notify"
local signal = require "cqueues.signal"
local auxlib = require "cqueues.auxlib"
local thread = require"cqueues.thread"

local watchdog = {}
local main
local logger

watchdog.run = function()
    local thr, pipe = thread.start(function(pipe, main, logger)
        local cqueues = require "cqueues"
        local sleep = cqueues.sleep
        local poll = cqueues.poll
        local watchdog = cqueues.new()

        watchdog:wrap(function()
            cqueues.sleep(10)
            logger:info("started watchdog")
            -- try to drain socket so we don't get stale alive
            -- tokens on successive iterations.
            while pipe:recv(-32) do
                poll(pipe, 10)
            end
            logger:Error( "main thread unresponsive\n")
            os.exit(false)
        end)

        local ok, why = watchdog:loop()

        logger:Error(string.format("dead-man thread failed: %s\n", why or "unknown error"),-1)

        os.exit(false)
    end, main, logger)

    main:wrap(function()
        local count = 1
        while count < 5 do
            cqueues.sleep(5)
            assert(pipe:write ("!\n"))
            logger:info("ey carumba!\n")
            count = count +1
            logger:info(count)
        end
        logger:info("ended")
    end)
end

watchdog.signals = function()
    signal.block(signal.SIGINT, signal.SIGHUP)
    local signo = signal.listen(signal.SIGINT, signal.SIGHUP):wait()
    logger:Info(string.format("exiting on signal (%s)", signal.strsignal(signo)), -2)
    os.exit(0)
end

local function new(mainloop, logger)
    main = mainloop
    logger = logger
    return watchdog
end
return {new = new}
