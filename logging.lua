---
-- @author russellh
-- @Copyright (c) 2016 Russell Haley
-- @license FreeBSD License. See License.txt

local configuration = require "configuration"
local strict = require "strict"

local log = {}
local conf
local debug_file

local ERROR = "ERROR"
local WARN =  "WARN"
local INFO =  "INFO"
local DEBUG = "DEBUG"
local DEBUG_OUT

--- Writes formatted message to lof file
-- @param level String error level. See local DEFINES
-- @param errno
-- @param fmt
-- @param ...
--
local function logtofile(level, errno, fmt, ...)
    if not debug_file then
        debug_file = io.open(conf.base_path .. "/" .. conf.debug_file_name, 'a')
    end

    local msg = os.date("%Y-%m-%d_%H%M%S") .. " - " .. level .. ": "
    if errno then msg = msg..string.format("Error No %d - ", errno) end;
    msg = msg .. string.format(fmt,...)
    msg = msg .. "\n"
    if DEBUG_OUT then
        if level == ERROR then
            for ln, nl in msg:gmatch "([^\n]*)(\n?)" do
                if #ln > 0 or #nl > 0 then
                    io.stderr:write(string.format("%s: %s\n", progname, ln))
                end
            end
        else
            print(msg)
        end

    end
    return debug_file:write(msg)
end

log.LogError = function(errno, fmt, ...)
    return Log(ERROR, errno, fmt, ...)
end

log.LogWarn = function(errno, fmt, ...)
    return Log(WARN, errno, fmt, ...)
end

log.LogInfo = function(fmt, ...)
    return Log(INFO, fmt, ...)
end

log.LogDebug = function(fmt, ...)
    return Log(DEBUG, fmt, ...)
end


log.Close = function()
    debug_file:close()
end

local function new(confPath, showDebug)
    if type(confPath) == "string" then
        conf = configuration.new(confPath)
    else
        error("confPath must be a string file path.")
    end
    if showDebug then DEBUG_OUT = true end;
end