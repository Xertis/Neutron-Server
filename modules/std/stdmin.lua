local data_buffer = require "lib/public/data_buffer"

_G['$VoxelOnline'] = "server"

--- STRING

function string.first_up(str)
    return (str:gsub("^%l", string.upper))
end

function string.type(str)
    if not str then
        return "nil", function (s)
            if s then
                return s
            end
        end
    end

    str = str:lower()

    if tonumber(str) then
        return "number", tonumber
    elseif str == "true" or str == "false" then
        return "boolean", function(s) return s:lower() == "true" end
    elseif pcall(json.parse, str) then
        return "table", json.parse
    end

    return "string", tostring
end

function string.trim_quotes(str)
    if not str then
        return
    end

    if str:sub(1, 1) == "'" or str:sub(1, 1) == '"' then
        str = str:sub(2)
    end

    if str:sub(-1) == "'" or str:sub(-1) == '"' then
        str = str:sub(1, -2)
    end

    return str
end

-- TIME

function time.formatted_time()
    local time_table = os.date("*t")

    local date = string.format("%04d/%02d/%02d", time_table.year, time_table.month, time_table.day)
    local time = string.format("%02d:%02d:%02d", time_table.hour, time_table.min, time_table.sec)

    local milliseconds = string.format("%03d", math.floor((os.clock() % 1) * 1000))

    local utc_offset = os.date("%z")
    if not utc_offset then
        utc_offset = "+0000"
    end

    return string.format("%s %s.%s%s", date, time, milliseconds, utc_offset)
end

function time.day_time_to_uint16(time)
    return math.floor(time * 65535 + 0.5)
end

--- LOGGER

logger = {}

function logger.log(text, type)
    type = type or 'I'

    text = string.first_up(text)

    local source = file.name(debug.getinfo(2).source)
    local out = '[' .. string.left_pad(source, 20) .. '] ' .. text

    local uptime = time.formatted_time()

    local timestamp = string.format("[%s] %s", type, uptime)

    local path = "export:server.log"
    local message = timestamp .. string.left_pad(out, #out+33-#timestamp)
    print(message)

    if not file.exists(path) then
        file.write(path, "")
    end

    local content = file.read(path)

    if #content > 600000 then
        content = ''
    end

    file.write(path, content .. '\n' .. message)
end

--- TABLE

table.unpack = unpack

function table.keys(t)
    local keys = {}

    for key, _ in pairs(t) do
        table.insert(keys, key)
    end

    return keys
end

function table.freeze(original)
    if type(original) ~= "table" then
        return original
    end

    local proxy = {}
    setmetatable(proxy, {
        __index = function(_, key)
            if type(original[key]) == "table" then
                original[key].__keys = table.keys(original[key])
            end
            return table.freeze(original[key])
        end,
        __metatable = false,
        __newindex = function()
            error("table is read-only")
        end,
    })

    return proxy
end

function table.freeze_unpack(arr)
    local i = 1
    local res = {}

    while arr[i] ~= nil do
        table.insert(res, arr[i])
        i = i + 1
    end

    return res
end

function table.to_arr(tbl, pattern)
    local res = {}

    for i, val in ipairs(pattern) do
        res[i] = tbl[val]
    end

    return res
end

function table.to_dict(tbl, pattern)
    local res = {}

    for i, val in ipairs(pattern) do
        res[val] = tbl[i]
    end

    return res
end

function table.has(t, x)
    for i,v in pairs(t) do
        if v == x then
            return true
        end
    end
    return false
end

function table.easy_concat(tbl)
    local output = ""
    for i, value in pairs(tbl) do
        output = output .. tostring(value)
        if i ~= #tbl then
            output = output .. ", "
        end
    end
    return output
end

function table.equals(tbl1, tbl2)
    return table.easy_concat(tbl1) == table.easy_concat(tbl2)
end

--- MATH

function math.euclidian(x1, y1, z1, x2, y2, z2)
    return ((x1 - x2) ^ 2 + (y1 - y2) ^ 2 + (z1 - z2) ^ 2) ^ 0.5
end

-- FUNCTIONS

functions = {}

function functions.watch_dog(func) -- Считает и выводит количество вызовов переданной функции
    local calls = 0
    return function(...)
        calls = calls + 1
        logger.log(string.format("%s calling from %s", calls, debug.getinfo(2).source), "T")
        return func(...)
    end
end

-- BJSON

function bjson.archive_tobytes(tbls, gzip)
    local db = data_buffer:new()
    db:put_uint16(#tbls)

    for _, tbl in ipairs(tbls) do
        local db2 = data_buffer:new(bjson.tobytes(tbl, gzip))
        db:put_int64(db2:size())
        db:put_bytes(db2.bytes)
    end

    return db.bytes
end

function bjson.archive_frombytes(bytes)
    local db = data_buffer:new(bytes)
    local len = db:get_uint16()
    local res = {}

    for _=1, len do
        local size = db:get_int64()
        table.insert(res, bjson.frombytes(db:get_bytes(size)))
    end

    return res
end

-- FILE

local function iter(table, idx)
    idx = idx + 1
    local v = table[idx]
    if v then
        return idx, v
    end
end

local function start_at(table, idx)
    return iter, table, idx-1
end

function file.recursive_list(path)
    local paths = {}
    for _, unit in ipairs(file.list(path)) do
        unit = unit:gsub(":/+", ":")

        if file.isfile(unit) then
            table.insert(paths, unit)
        else
            table.merge(paths, file.recursive_list(unit))
        end
    end

    return paths
end

function file.join(...)
    local parts = nil
    local path = nil

    if type(...) == "table" then
        parts = ...
    else
        parts = {...}
    end

    if #parts > 0 and type(parts[1]) == "string" and parts[1]:sub(-1) == ":" then
        path = parts[1]

        for i = 2, #parts do
            path = path .. parts[i] .. '/'
        end
    else
        path = table.concat(parts, "/")
        path = path:gsub("/+", "/")
    end

    if path:sub(-1) == "/" then
        path = path:sub(1, -2)
    end

    return path
end

function file.split(path)
    local parts = {}

    for part in string.gmatch(path, "[^/:]+") do
        table.insert(parts, part)
    end

    return parts
end

function file.mktree(path, value)
    path = file.split(path)
    path[1] = path[1] .. ':'
    local split_path = table.sub(path, 1, #path-1)

    file.mkdirs(file.join(split_path))
    file.write_bytes(file.join(path), value)
end

-- AUDIO

audio.play_stream = function () end
audio.play_stream_2d = function () end
audio.play_sound = function () end
audio.play_sound_2d = function () end


-- INVENTORY

function inventory.inv_to_tbl(invid)
    local size = inventory.size(invid)
    local tbl = {}

    for i=1, size do
        local item_id, item_count = inventory.get(invid, i)
        local item_data = inventory.get_all_data(invid, i)

        table.insert(tbl, {
            id = item_id,
            count = item_count,
            data = item_data
        })
    end

    return tbl
end

function inventory.tbl_to_inv(tbl, invid)
    for i, item in ipairs(tbl) do
        inventory.set(invid, i, item.id, item.count)

        for key, value in pairs(item.data) do
            inventory.set_data(invid, i, key, value)
        end
    end
end

-- BIT

function bit.tobits(num, is_sign)
    local is_negative = nil
    if is_sign then
        is_negative = num < 0
    end

    num = math.abs(num)

    local t={}
    local rest = nil
    while num>0 do
        rest=math.fmod(num,2)
        t[#t+1]=rest
        num=(num-rest)/2
    end

    if is_sign then
        table.insert(t, is_negative and 1 or 0)
    end
    return t
end

function bit.tonum(bits, is_sign)
    local num = 0
    for i, bit in ipairs(bits) do
        local val = bit == 1 and 2 or 0
        local j = i
        local degree = 0
        if not is_sign then j = j - 1 end

        degree = #bits - j

        if not is_sign or i < #bits then
            num = num + val^(degree-1)
        end
    end

    if is_sign then
        local is_negative = bits[#bits]

        if is_negative == 1 then
            num = -num
        end
    end

    return num
end

-- OTHER

function cached_require(path)
    if not string.find(path, ':') then
        local prefix, _ = parse_path(debug.getinfo(2).source)
        return cached_require(prefix..':'..path)
    end
    local prefix, file = parse_path(path)
    return package.loaded[prefix..":modules/"..file..".lua"]
end

function start_require(path)
    if not string.find(path, ':') then
        local prefix, _ = parse_path(debug.getinfo(2).source)
        return start_require(prefix..':'..path)
    end

    local old_path = path
    local prefix, file = parse_path(path)
    path = prefix..":modules/"..file..".lua"

    if not _G["/$p"] then
        return require(old_path)
    end

    return _G["/$p"][path]
end