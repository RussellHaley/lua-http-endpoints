--
-- # file
--
-- Basic file functions for Lua.
--
-- **License:** MIT  
--  **Source:** [GitHub](https://github.com/gummesson/file.lua)
--

-- ## References

local io, os, error = io, os, error

-- ## file
--
-- The namespace.
--
local file = {}

-- ### file.exists
--
-- Determine if the file in the `path` exists.
--
-- - `path` is a string.
--
function file.exists(path)
    local file = io.open(path, 'rb')
    if file then
        file:close()
    end
    return file ~= nil
end

-- ### file.read
--
-- Return the content of the file by reading the given `path` and `mode`.
--
-- - `path` is a string.
-- - `mode` is a string.
--
function file.read(path, mode)
    mode = mode or '*a'
    local file, err = io.open(path, 'rb')
    if err then
        error(err)
    end
    local content = file:read(mode)
    file:close()
    return content
end

-- ### file.write
--
-- Write to the file with the given `path`, `content` and `mode`.
--
-- - `path`    is a string.
-- - `content` is a string.
-- - `mode`    is a string.
--
function file.write(path, content, mode)
    mode = mode or 'w'
    local file, err = io.open(path, mode)
    if err then
        error(err)
    end
    file:write(content)
    file:close()
end

-- ### file.copy
--
-- Copy the file by reading the `src` and writing it to the `dest`.
--
-- - `src`  is a string.
-- - `dest` is a string.
--
function file.copy(src, dest)
    local content = file.read(src)
    file.write(dest, content)
end

-- ### file.move
--
-- Move the file from `src` to the `dest`.
--
-- - `src`  is a string.
-- - `dest` is a string.
--
function file.move(src, dest)
    os.rename(src, dest)
end

-- ### file.remove
--
-- Remove the file from the given `path`.
--
-- - `path` is a string.
--
function file.remove(path)
    os.remove(path)
end

function file.getfilepath(path)
    print("not implemented")
end

function file.getfilename(path)
    i = path:find("/")
    if i == nil then
        return path:match("^.+\\(.+)$")
    else
        return path:match("^.+/(.+)$")
    end
end

function file.getfileextension(path)
    ext = path:match "[^.]+$"
    if #ext == #url then
        return nil
    else
        return ext
    end
end

function file.getlastmodified(path)
    local f = io.popen("stat -c %Y testfile")
    local last_modified = f:read()
    f:close()
end

function file.getmd5Hex(path)
    local content = file.read(path)
    local md5 = require 'md5'
    return md5.sumhexa(content)
end

function file.getcrc32(path)
    local CRC = require 'digest.crc32lua'
    local content = open(path)
    return CRC.crc32(content)
end

function file.createhashfile(path, hashFileName)
    print("path from file", path)
    content = file.read(path)
    local md5 = require 'md5'
    local md5_as_hex = md5.sumhexa(content)
    hashFile = io.open(hashFileName, 'w')
    hashFile:write(md5_as_hex)
    hashFile:close()
end

-- ## Exports
--
-- Export `file` as a Lua module.
--
return file
