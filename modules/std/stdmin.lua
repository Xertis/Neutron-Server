local data_buffer = require "lib/public/data_buffer"

_G['$VoxelOnline'] = "server"

--- STRING

function string.padding(str, size, char)
    char = char == nil and " " or char
    local padding = math.floor((size - #str) / 2)
    return string.rep(char, padding) .. str .. string.rep(char, padding)
end

function string.left_padding(str, size, char)
    char = char == nil and " " or char
    local left_padding = size - #str
    return string.rep(char, left_padding) .. str
end

function string.right_padding(str, size, char)
    char = char == nil and " " or char
    local right_padding = size - #str
    return str .. string.rep(char, right_padding)
end

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

--- LOGGER

logger = {}

function logger.log(text, type)
    type = type or 'I'

    text = string.first_up(text)

    local source = file.name(debug.getinfo(2).source)
    local out = '[' .. string.left_padding(source, 20) .. '] ' .. text

    local uptime = time.formatted_time()

    local timestamp = string.format("[%s] %s", type, uptime)

    print(timestamp .. string.left_padding(out, #out+33-#timestamp))
end

--- TABLE

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

function table.merge(t1, t2)
    for i, v in pairs(t2) do
        if type(i) == "number" then
            t1[#t1 + 1] = v
        elseif t1[i] == nil then
            t1[i] = v
        end
    end

    return t1
end

function table.map(t, func)
    for i, v in pairs(t) do
        t[i] = func(i, v)
    end

    return t
end

function table.filter(t, func)

    for i = #t, 1, -1 do
        if not func(i, t[i]) then
            table.remove(t, i)
        end
    end

    local size = #t

    for i, v in pairs(t) do
        local i_type = type(i)
        if i_type == "number" then
            if i < 1 or i > size then
                if not func(i, v) then
                    t[i] = nil
                end
            end
        else
            if not func(i, v) then
                t[i] = nil
            end
        end
    end

    return t
end

function table.set_default(t, key, default)
    if t[key] == nil then
        t[key] = default
        return default
    end

    return t[key]
end

function table.flat(t)
    local flat = {}

    for _, v in pairs(t) do
        if type(v) == "table" then
            table.merge(flat, v)
        else
            table.insert(flat, v)
        end
    end

    return flat
end

function table.deep_flat(t)
    local flat = {}

    for _, v in pairs(t) do
        if type(v) == "table" then
            table.merge(flat, table.deep_flat(v))
        else
            table.insert(flat, v)
        end
    end

    return flat
end

function table.sub(arr, start, stop)
    local res = {}
    start = start or 1
    stop = stop or #arr

    for i = start, stop do
        table.insert(res, arr[i])
    end

    return res
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

function math.sum(...)
    local numbers = nil
    local sum = 0

    if type(...) == "table" then
        numbers = ...
    else
        numbers = {...}
    end

    for _, v in ipairs(numbers) do
        sum = sum + v
    end

    return sum
end

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

    print(file.join(split_path))
    print(file.join(path))

    file.mkdirs(file.join(split_path))
    file.write_bytes(file.join(path), value)
end

-- AUDIO

audio.play_stream = function () end
audio.play_stream_2d = function () end
audio.play_sound = function () end
audio.play_sound_2d = function () end


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