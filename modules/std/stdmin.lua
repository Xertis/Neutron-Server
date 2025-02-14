local data_buffer = require "lib/public/data_buffer"

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

--- LOGGER

logger = {}

function logger.log(text, type)
    type = type or 'I'

    text = string.first_up(text)

    local source = file.name(debug.getinfo(2).source)
    local out = '[' .. string.left_padding(source, 20) .. '] ' .. text

    local uptime = time.uptime()
    local deltatime = tostring(math.round(time.delta(), 8))

    uptime = string.formatted_time(uptime)
    uptime = string.format("%s:%s:%s", uptime.h, uptime.m, uptime.s)

    local timestamp = string.format("[%s] %s | %s", type, uptime, deltatime)

    print(timestamp .. string.left_padding(out, #out+33-#timestamp))
end

--- TABLE

function table.freeze(original)
    if type(original) ~= "table" then
        return original
    end

    local proxy = {}
    setmetatable(proxy, {
        __index = function(_, key)
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
    for i, v in pairs(t) do
        if not func(i, v) then
            t[i] = nil
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