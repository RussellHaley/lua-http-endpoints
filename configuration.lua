--
-- Created by IntelliJ IDEA.
-- User: russellh
-- Date: 9/26/16
-- Time: 11:37 PM
-- To change this template use File | Settings | File Templates.
--

--[[
-- Load a conf file using loadstring
--Remarks: This doesn't currently work, even though the table seems valid
-- ]]
local conf = {}

local function loadConfFile(fn)
    local f = io.open(fn, 'r')
    if f == nil then return {} end
    local str = f:read('*a') .. '\n'
    f:close()
    local res = 'return {'
    for line in str:gmatch("(.-)[\r\n]") do
        line = line:gsub('^%s*(.-)%s*$"', '%1') -- trim line
        -- ignore empty lines and comments
        if line ~= '' and line:sub(1, 1) ~= '#' then
            line = line:gsub("'", "\\'") -- escape all '
            line = line:gsub("=%s*", "='", 1)
            res = res .. line .. "',"
        end
    end
    res = res:sub(1, -2)
    res = res .. '}'

    print(res)
    --t = {server_port='8000',server_url ='localost',base_path ='confFilePath',data_dir_name ='data'}
    --local t = assert(loadstring(res)())
    return t -- { server_port = '8000', server_url = 'localhost', base_path = 'confFilePath', data_dir_name = 'data' }
end

--[[
-- Descrption: Reads a configuration file in key=value notation.
--Can include a couple of transforms but it really needs to
--use lpeg to do the transformations.
-- ]]
local function ReadConf(filePath, removequotes, debug)
    local fp = io.open(filePath, "r")
    if fp then
        --Add our own path as a control mechanism (:)
        conf[":conf_file_path"] = filePath
        --loop through each line of the file
        for line in fp:lines() do
            --no idea what this does
            line = line:match("%s*(.+)")
            --if the line is valid and doesn't start with # or ; then continue
            if line and line:sub(1, 1) ~= "#" and line:sub(1, 1) ~= ";" then
                --Match on the = and get our option and it's value
                local option, value = line:match('%s*(.-)%s*=%s*(.+)%s*')
                if not option then
                    error("Unexplained match that has a key but no option: " .. line)
                elseif not value then
                    --an option key with no value is false
                    conf[option] = false
                else
                    --Success
                    --Check for comma, If no comma, single value
                    if not value:find(",") then
                        if removequotes == true then
                            conf[option] = value:gsub("\"", "")
                        else
                            conf[option] = value
                        end
                    else
                        --This line has a comma in it. There is more than
                        -- one value item
                        value = value .. ","
                        conf[option] = {}
                        for entry in value:gmatch("%s*(.-),") do
                            conf[option][#conf[option] + 1] = entry
                        end
                    end
                end
            end
        end
        fp:close()
    else
        --No file. die.
        error("File does not exist: " .. filePath)
    end

    if debug == true then
        for i, v in pairs(conf) do
            print(i, v)
        end
    end
    return conf
end

local function SetItem(table, item, value)
    --Read in the file and look for the "Item value
    local conf = file.read(table[":conf_file_path"])
    local i, j = conf:find(item)
    if i then --if item is found
    --replace item=<anything> with item=value
    -- THIS SUBSTITUTION DOESN"T WORK PROPERLY IT ONLY FINDS LINEFEED not the end of string
    conf = conf:gsub(item .. "=.-[%\n|$]", item .. "=" .. value .. "\n")
    else --item wasn't found
    if conf:sub(#conf, 1) == "\n" then
        conf = conf .. item .. "=" .. value
    else
        conf = conf .. "\n" .. item .. "=" .. value
    end
    end
    print(conf)
    file.write(ConfFileName, conf)
end

ReadConf.SetConfItem = function(item, enabled)
    --print(item,enabled)
    SetConf(item, enabled)
end



return { new = ReadConf; }

--[[
--  Well, here's an LPeg solution.  I'll walk through it in the hopes you
understand it.

-- ******************************************************
-- Loads the LPeg module.  Should be self explanitory.
-- ******************************************************

local lpeg = require "lpeg"

-- *****************************************************
-- Cache some LPeg functions as locals.  This is primarily because I'm too
-- lazy to type 'lpeg.C' and 'lpeg.P' all over the place, leading to less
-- code clutter.  I'm only including the functions I'm using.
-- *****************************************************

local Carg = lpeg.Carg -- returns argument to pattern:match() as capture
local Cmt  = lpeg.Cmt  -- runs a function at match time over the captured data
local Cs   = lpeg.Cs   -- returns a capture with substitued data
local C    = lpeg.C    -- simple capture
local S    = lpeg.S    -- define a set of characters to match
local P    = lpeg.R    -- another way to define a set of characters to match using ranges
local R    = lpeg.P    -- literal string match

-- ********************************************************
-- Some simple patterns.
-- SP will match spaces or tabs (as a set) zero or more times.
-- EQ is a literal '=' surrounded by optional whitespace.
-- LF is the end-of-line marker.  It will match an optional CR character
--    (used on Windows, not used at all on Linux or MacOSX) and a LF
--    character (used by all).
-- ********************************************************

local SP   = S" \t"^0           -- optional white space
local EQ   = SP * P"=" * SP     -- literal '='
local LF   = P"\r"^-1 * P"\n"   -- end of line, OS neutral

-- *********************************************************
-- 'id' is a pattern to match a value name.  I'm being liberal in assuming
-- value names are made up of letters, digits, underscore and dashes.  Yes,
-- not only will this catch names like:
--
--      item
--      fred
--      a_name_for-something_
--
-- but also
--
--      3
--      23-skidoo
--
-- 'val' is defined as ASCII characters from space to ~ (the entire graphic
-- ASCII range) plus the tab character.
-- *********************************************************

local id   = R("09","AZ","az","__","--")^1      -- name of var
local val  = R("\t\t"," ~")^0                   -- rest of line

-- *********************************************************
-- Capture a name/value pair as two distinct values.
-- *********************************************************

local pair = C(id) * EQ * C(val)

-- *********************************************************
-- The meat of the function.  When a pair is found, we also include the
-- first argument of the match function as a capture (basically, it contans
-- the name of the item and the new value---more on this below).  When the
-- match is found, immediately call the given function with our three
-- captures (the 'subject' and 'pos' argument are always passed---'subject'
-- being the entire string being matched, 'pos' just past the last character
-- matched).  We compre the id with the one we're looking for, and if it
-- matches, we return 'pos' (telling Cmt() that we succeeded) and a new
-- string containing 'item=newvalue'; otherwise, we didn't find what we were
-- looking for, and just return 'pos'.
--
-- We then check to make sure the line ends with a LF sequence.
-- *********************************************************

local line = Cmt(pair * Carg(1),function(subject,pos,name,val,arg)
  if name == arg.item then
    return pos,string.format("%s=%s",name,arg.value)
  else
    return pos
  end
end) * LF

-- *********************************************************
-- The other half of the work.  we repeat looking for name/value pairs over
-- the entire input:
--
--      (line + P(1))^1
--
-- In case we don't match a name/value pair, we still match anything so we
-- don't error out.  This ensures we go over all input.
--
-- This loop is wrapped in the Cs() function, which causes some matches to
-- be substituted with a new value.  The function we passed to Cmt() returns
-- a new value when we find what we are looking for, otherwise it doesn't.
-- Any input not substituted will remain as-is.
-- *********************************************************

local conf = Cs((line + P(1))^1)

-- *********************************************************
-- A simple function to scan the given data, changing item to have the new
-- value.  We call conf:match() with an additional table (retreived by the
-- Carg() function) with the name of the item and the new value.  We then
-- print the old data and the new data to show it changing.
-- *********************************************************

local function SetItem(data,item,value)
  local x = conf:match(data,1,{ item = item , value = value })
  print(data)
  print()
  print(x)
end

-- *********************************************************
-- Some sample data and a test run.
-- *********************************************************

local contents = [[
one = two
three=four
; comment---this should come out okay
This_is_a_header=some values go here
item = old_value
other_header_name=this that the other
_test=foobar
]]

--SetItem(contents,'item','new value')
-- ]]