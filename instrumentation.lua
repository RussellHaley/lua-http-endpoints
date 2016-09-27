--[[
1) start a new application database for persistent values
- get basedir from a config file
- open a new directory under basedir - timestamped for execution start

- keys will be strings of constants (how to ensure uniqness?)
	- where do defaults come from? application startup file?
	
	OR
	
- one key per "application", stored a lua table as the value.

]] --

local Instr = {}

local lightningmdb_lib = require("lightningmdb")
local lfs = require("lfs")
local lua_t = require("t")

--penlight


local lightningmdb = _VERSION >= "Lua 5.2" and lightningmdb_lib or lightningmdb

local MDB = setmetatable({}, {
    __index = function(t, k)
        return lightningmdb["MDB_" .. k]
    end
})



local function protect(tbl)
    return setmetatable({}, {
        __index = tbl,
        __newindex = function(t, key, value)
            error("attempting to change constant " ..
                    tostring(key) .. " to " .. tostring(value), 2)
        end
    })
end

Instr.Stat = function()
    local e = lightningmdb.env_create()
    e:open(Instr["data_directory"], 0, 420)
    stat = e:stat()
    e:close()
    return stat

end



--[[
Writes values to the applications internal conf file. 
RH - This has a bug. If there is no final \\n then the 
Parsing doesn't always work. Need to improve the matching.
RH-2016-09-26 This is all wrong. If we have a conf table, then we should
put values in the tables and save that, not write directly to the file, because then we need to reload the whole thing.
--]]
--[[
function SetConf(item, value)
    --Read in the file and look for the "Item value
    conf = file.read(ConfFileName)
    i, j = conf:find(item)
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

Instr.SetConfItem = function(item, enabled)
    --print(item,enabled)
    SetConf(item, enabled)
end
]]

local function ReadConf(filePath)

    print("Opening file " .. filePath)
    local Conf
    local fp = io.open(filePath, "r")

    for line in fp:lines() do
        line = line:match("%s*(.+)")
        if line and line:sub(1, 1) ~= "#" and line:sub(1, 1) ~= ";" then
            local option = line:match("%S+"):lower()
            local value = line:match("%S*%s*(.*)")

            if not value then
                Conf[option] = true
            else
                if not value:find(",") then
                    Conf[option] = value
                else
                    value = value .. ","
                    Conf[option] = {}
                    for entry in value:gmatch("%s*(.-),") do
                        Conf[option][#Conf[option] + 1] = entry
                    end
                end
            end
        end
    end
    fp:close()
    return Conf
end

local function DirectoryExists(name)
    if type(name) ~= "string" then return false end
    local cd = lfs.currentdir()
    local is = lfs.chdir(name) and true or false
    print(is)
    print(name)
    lfs.chdir(cd)
    return is
end

--[[
Write Instrumentation
This function write the key value pairs in the Instrumentation table
to the application database. If the application dies, these values are
persisted for diagnostics.
]] --
Instr.WriteInstrumentation = function ()
    local e = lightningmdb.env_create()
    e:open(Instr["data_directory"], 0, 420)
    local t = e:txn_begin(nil, 0)
    local d = t:dbi_open(nil, 0)

    local count = 0

    for key, value in pairs(Instr) do
        local rc = t:put(d, key, value, MDB.NOOVERWRITE)
--        count = count + 1
    end

--    print("Total Items Added", count)
    t:commit()

    PrintStat(e)
    e:close()
end

--[[
--iterate through the data returned by LMDB
]]--
local function cursor_pairs(cursor_, key_, op_)
    return coroutine.wrap(function()
        local k = key_
        repeat
            k, v = cursor_:get(k, op_ or MDB.NEXT)
            if k then
                coroutine.yield(k, v)
            end
        until not k
    end)
end


local function GetUuid()
    local handle = io.popen("uuidgen")
    local val, lines = handle:read("*a")
    val = val:gsub("^%s*(.-)%s*$", "%1")
    return val
end

Instr.UpdateInstrumentation = function (key, value)
    local e = lightningmdb.env_create()
    e:open(Instr.data_directory, 0, 420)
    local t = e:txn_begin(nil, 0)
    local d = t:dbi_open(nil, 0)

    if not key then
        for i, v in ipairs(Instr) do
            t:put(d, i, v, 0)
        end
    else
        t:put(d,key,value,0)
    end

    t:commit()
    e:close()
end


Instr.ReadInstrumentation = function ()
    local e = lightningmdb.env_create()
    e:open(Instr.data_directory, 0, 420)
    local t = e:txn_begin(nil, MDB.RDONLY)
    local d = t:dbi_open(nil, 0)
    local cursor = t:cursor_open(d)

    local data = {}
    local k
    for k, v in cursor_pairs(cursor) do
        data:insert(k,v)
        print(k, v)
    end

    cursor:close()
    t:abort()
    e:close()
    return data
end

local function RemoveFileExtention(url)
    return url:gsub(".[^.]*$", "")
end


--[[function CheckContinue()
  print("continue?")
  s = io.read("*l") 
  if s:upper() == "N" then
   End()
  end    
end]]

Instr.Close = function()
    if Instr.rm_data_dir then
        os.execute("rm -rf " .. Instr.data_directory)
        print("database removed:".. Instr.data_directory )
    end
end


local function new(confName)

    local confFilePath = RemoveFileExtention(confName) .. ".conf"
    local Conf = ReadConf(confFilePath)
    --Build path some/path/to/data/2016-12-30_245959
    print(Conf["base_path"])
    Instr["data_directory"] = Conf["base_path"] .. "/" .. Conf["data_dir_name"] .. "/" .. os.date("%Y-%m-%d_%H%M%S")
    Instr.rm_data_dir = Conf.rm_data_dir
    if DirectoryExists(Instr.data_directory) then
        print("Found data directory. Using existing database.")
    else
        os.execute("mkdir -p " .. Instr.data_directory)
    end

    return Instr;
end
return {new = new;}

--[[function StartWatchDir(uri)
    --path, callback, timeout_in_milliseconds, exit_on_event, add_or_modify_only
  assert(Evq:add_dirwatch(uri, OnFilesystemChanged, 10000000, false, true))
end]]

--[[
function OnFilesystemChanged()
  print("GOt a hit")
  --CheckContinue()
  
end

function StopWatchDir(uri)
  
end
]]


--[[*****************************************************************
Name: Applicaiton-Base-1
Description: Sputtering start of the main application. Will attempt
to build a frameworl out of this now.
*****************************************************************--]]
--[[

Begin()



Instr["system_stat_boardtemp"] = "100c"
Instr["system_startup_guid"] = GetUuid()

--PrintTable(Instr)


UpdateInstrumentation()

ReadInstrumentation()

StopWatchDir()

End()]]
