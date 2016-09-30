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
local configuration = require("configuration")

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

local function DirectoryExists(name)
    if type(name) ~= "string" then return false end
    local cd = lfs.currentdir()
    local is = lfs.chdir(name) and true or false
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
    Instr[key] = value
    e:open(Instr.data_directory, 0, 420)
    local t = e:txn_begin(nil, 0)
    local d = t:dbi_open(nil, 0)

    t:put(d, key, value, 0)

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
    data[":data_directory"] = Instr.data_directory
    local k
    for k, v in cursor_pairs(cursor) do
        data[k] = v
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


local function new(confFilePath)


    local conf = configuration.new(confFilePath)

    Instr["data_directory"] = conf["base_path"] .. "/" .. conf["data_dir_name"] .. "/" .. os.date("%Y-%m-%d_%H%M%S")
    Instr.rm_data_dir = conf.rm_data_dir
    if DirectoryExists(Instr.data_directory) then
        print("Found data directory. Using existing database.")
    else
        local count = 0
        for slash in Instr.data_directory:gmatch("/") do
            count = count + 1
        end

        --local first_slash = Instr.data_directory:gmatch("/")
        if count <= 1 then
            error("The filename is invalid. Check the base_path and data_dir values in the config file. Attempted data dir: " .. Instr.data_directory)
        else
            os.execute("mkdir -p " .. Instr.data_directory)
        end
    end

    return Instr;
end

return {new = new;}

--[[function StartWatchDir(uri)
    --path, callback, timeout_in_milliseconds, exit_on_event, add_or_modify_only
  assert(Evq:add_dirwatch(uri, OnFilesystemChanged, 10000000, false, true))
end]]

