local data_buffer = require "lib/public/data_buffer"

_G['$VoxelOnline'] = "server"

--- PLAYER

function player.get_dir(pid)
    local yaw, pitch = player.get_rot(pid)
    local yaw_rad = math.rad(yaw)
    local pitch_rad = math.rad(pitch)

    local x = math.cos(pitch_rad) * math.sin(yaw_rad)
    local y = -math.sin(pitch_rad)
    local z = math.cos(pitch_rad) * math.cos(yaw_rad)

    return {-x, -y, -z}
end

--- STRING

function string.first_up(str)
    return (str:gsub("^%l", string.upper))
end

function string.first_low(str)
    return (str:gsub("^%u", string.lower))
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

function string.multiline_concat(str1, str2, space)
    space = space or 0
    local str1_lines = {}
    for line in str1:gmatch("([^\n]+)") do
        table.insert(str1_lines, line)
    end

    local str2_lines = {}
    for line in str2:gmatch("([^\n]+)") do
        table.insert(str2_lines, line)
    end

    local max_len = 0
    for _, line in ipairs(str1_lines) do
        max_len = math.max(max_len, #line)
    end

    local len = max_len + space

    local result = {}
    for i, line in ipairs(str1_lines) do
        local str2_line = str2_lines[i] or ''
        table.insert(result, line .. string.rep(' ', len-#line) .. str2_line)
    end

    return table.concat(result, '\n')
end

function string.soft_space_split(str)
    local result = {}
    local current = {}
    local in_quotes = false
    local bracket_level = 0
    local brace_level = 0

    for i = 1, #str do
        local char = str:sub(i, i)

        if char == '"' and bracket_level == 0 and brace_level == 0 then
            in_quotes = not in_quotes
            table.insert(current, char)
        elseif not in_quotes then
            if char == '[' then
                bracket_level = bracket_level + 1
            elseif char == ']' then
                bracket_level = bracket_level - 1
            elseif char == '{' then
                brace_level = brace_level + 1
            elseif char == '}' then
                brace_level = brace_level - 1
            elseif char == ' ' and bracket_level == 0 and brace_level == 0 then
                if #current > 0 then
                    table.insert(result, table.concat(current))
                    current = {}
                end
                goto continue
            end
            table.insert(current, char)
        else
            table.insert(current, char)
        end

        ::continue::
    end

    if #current > 0 then
        table.insert(result, table.concat(current))
    end

    return result
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

function logger.log(text, type, only_save)
    type = type or 'I'
    type = type:upper()

    text = string.first_low(text)

    local source = file.name(debug.getinfo(2).source)
    local out = '[' .. string.left_pad(source, 20) .. '] ' .. text

    local uptime = time.formatted_time()

    local timestamp = string.format("[%s] %s", type, uptime)

    local path = "export:server.log"
    local message = timestamp .. string.left_pad(out, #out+33-#timestamp)

    if not only_save then
        print(message)
    end

    if not file.exists(path) then
        file.write(path, "")
    end

    local content = file.read(path)

    if #content > 600000 then
        content = ''
    end

    file.write(path, content .. message .. '\n')
end

--- TABLE

table.unpack = unpack

function table.get_default(tbl, ...)
    for _, key in ipairs({...}) do
        if not tbl[key] then
            return nil
        end

        tbl = tbl[key]
    end

    return tbl
end

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

function table.to_serializable(t)
    local serializable = {}

    for k, v in pairs(t) do
        local item_type = type(v)
        if item_type == "table" then
            serializable[k] = table.to_serializable(v)
        elseif table.has({"number", "string", "boolean"}, item_type) then
            serializable[k] = v
        end
    end

    return serializable
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
    if table.count_pairs(tbl1) ~= table.count_pairs(tbl2) then
        return false
    end

    for key, value in pairs(tbl1) do
        if value ~= tbl2[key] then
            return false
        end
    end

    return true
end

function table.deep_equals(tbl1, tbl2)
    if type(tbl1) ~= type(tbl2) then
        return false
    end

    if type(tbl1) ~= "table" then
        return tbl1 == tbl2
    end

    if tbl1 == tbl2 then
        return true
    end

    local count1 = 0
    for _ in pairs(tbl1) do count1 = count1 + 1 end
    local count2 = 0
    for _ in pairs(tbl2) do count2 = count2 + 1 end
    if count1 ~= count2 then
        return false
    end

    for key, value1 in pairs(tbl1) do
        local value2 = tbl2[key]
        if value2 == nil or not table.deep_equals(value1, value2) then
            return false
        end
    end

    return true
end

function table.diff(tbl1, tbl2)
    local set1 = {}
    local set2 = {}
    for _, v in ipairs(tbl1) do
        set1[v] = true
    end
    for _, v in ipairs(tbl2) do
        set2[v] = true
    end

    local diff_tbl1 = {}
    for _, v in ipairs(tbl1) do
        if not set2[v] then
            table.insert(diff_tbl1, v)
        end
    end

    local diff_tbl2 = {}
    for _, v in ipairs(tbl2) do
        if not set1[v] then
            table.insert(diff_tbl2, v)
        end
    end

    return diff_tbl1, diff_tbl2
end

--- MATH

function math.euclidian3D(x1, y1, z1, x2, y2, z2)
    return ((x1 - x2) ^ 2 + (y1 - y2) ^ 2 + (z1 - z2) ^ 2) ^ 0.5
end

function math.euclidian2D(x1, y1, x2, y2)
    return ((x1 - x2) ^ 2 + (y1 - y2) ^ 2) ^ 0.5
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

function functions.args_check(name, args)
    for key, v in pairs(args) do
        if not v then
            error(string.format("type error: expected %s, got none in function '%s'", key, name))
        end
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

function inventory.get_inv(invid)
    local inv_size = inventory.size(invid)
    local res_inv = {}

    for slot = 0, inv_size - 1 do
       local item_id, count = inventory.get(invid, slot)

       if item_id ~= 0 then
          local item_data = inventory.get_all_data(invid, slot)
          table.insert(res_inv, {item_id, count, item_data})
       else
          table.insert(res_inv, 0)
       end
    end

    return res_inv
 end

 function inventory.set_inv(invid, res_inv)
    for i, item in ipairs(res_inv) do
       local slot = i - 1
       if item ~= 0 then
          local item_id, count, item_data = unpack(item)

          inventory.set(invid, slot, item_id, count)

          if item_data then
             for name, value in pairs(item_data) do
                inventory.set_data(invid, slot, name, value)
             end
          end
       else
          inventory.set(invid, slot, 0, 0)
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

-- VEC

function vec3.lerp(cur_pos, target_pos, t)
    t = math.clamp(t, 0, 1)
    local diff = vec3.sub(target_pos, cur_pos)
    local scaledDiff = vec3.mul(diff, t)
    return vec3.add(cur_pos, scaledDiff)
end

function vec3.culling(view_dir, pos, target_pos, fov_degrees)
    if vec3.length(view_dir) == 0 then
        return false
    end

    local to_target = vec3.sub(target_pos, pos)

    if vec3.length(to_target) == 0 then
        return false
    end

    local view_dir_norm = vec3.normalize(view_dir)
    local to_target_norm = vec3.normalize(to_target)

    local dot_product = vec3.dot(view_dir_norm, to_target_norm)
    dot_product = math.max(-1, math.min(1, dot_product))

    local angle_rad = math.acos(dot_product)
    local angle_deg = math.deg(angle_rad)

    return angle_deg <= (fov_degrees+30) / 2
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

function tohex(num)
    return string.format("%x", num)
end