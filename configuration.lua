--
-- Created by IntelliJ IDEA.
-- User: russellh
-- Date: 9/26/16
-- Time: 11:37 PM
-- To change this template use File | Settings | File Templates.
--

local function ReadConf(filePath)
--    print("Opening file " .. filePath)
    local conf
    local fp = io.open(filePath, "r")

    if fp then
        conf.conf_file_path = filePath
    for line in fp:lines() do
        line = line:match("%s*(.+)")
        if line and line:sub(1, 1) ~= "#" and line:sub(1, 1) ~= ";" then
            local option = line:match("%S+"):lower()
            local value = line:match("%S*%s*(.*)")

            if not value then
                conf[option] = true
            else
                if not value:find(",") then
                    conf[option] = value
                else
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
    conf.SetItem = SetItem
    end
    return conf
end

local function SetItem(table, item, value)
    --Read in the file and look for the "Item value
    local conf = file.read(table.conf_file_path)
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

SetConfItem = function(item, enabled)
    --print(item,enabled)
    SetConf(item, enabled)
end