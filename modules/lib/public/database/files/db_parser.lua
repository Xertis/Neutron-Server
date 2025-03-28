local db = require "lib/public/data_buffer"

local VERSION = 0

local module = {}

TYPES = {
    codes = {
        null       = 0,
        int8       = 1,
        int16      = 2,
        int32      = 3,
        int64      = 4,
        uint8      = 5,
        uint16     = 6,
        uint32     = 7,
        string     = 8,
        norm8      = 9,
        norm16     = 10,
        float32    = 11,
        float64    = 12,
        bool       = 13
    },

    indexes = {
        [0] = "null",   -- код 0
        "int8",         -- код 1
        "int16",        -- код 2
        "int32",        -- код 3
        "int64",        -- код 4
        "uint8",        -- код 5
        "uint16",       -- код 6
        "uint32",       -- код 7
        "string",       -- код 8
        "norm8",        -- код 9
        "norm16",       -- код 10
        "float32",      -- код 11
        "float64",      -- код 12
        "bool"          -- код 13
    },

    names = {
        ["null"]      = "null",
        ["int8"]      = "int8",
        ["int16"]     = "int16",
        ["int32"]     = "int32",
        ["int64"]     = "int64",
        ["uint8"]     = "uint8",
        ["uint16"]    = "uint16",
        ["uint32"]    = "uint32",
        ["string"]    = "string",
        ["norm8"]     = "norm8",
        ["norm16"]    = "norm16",
        ["float32"]   = "float32",
        ["float64"]   = "float64",
        ["bool"]      = "bool"
    }
}

module.types = {
    indexes = TYPES.indexes,
    codes = TYPES.codes
}

local function put_value(buf, value, type)
    if type == TYPES.names.int8 then
        if value >= 0 then
            buf:put_byte(value)
        else
            buf:put_byte(127 - value)
        end
    elseif type == TYPES.names.int16 then
        buf:put_sint16(value)
    elseif type == TYPES.names.int32 then
        buf:put_sint32(value)
    elseif type == TYPES.names.int64 then
        buf:put_int64(value)
    elseif type == TYPES.names.uint8 then
        buf:put_byte(value)
    elseif type == TYPES.names.uint16 then
        buf:put_uint16(value)
    elseif type == TYPES.names.uint32 then
        buf:put_uint32(value)
    elseif type == TYPES.names.string then
        buf:put_string(value)
    elseif type == TYPES.names.norm8 then
        buf:put_norm8(value)
    elseif type == TYPES.names.norm16 then
        buf:put_norm16(value)
    elseif type == TYPES.names.float32 then
        buf:put_float32(value)
    elseif type == TYPES.names.float64 then
        buf:put_float64(value)
    elseif type == TYPES.names.timestamp then
        buf:put_int64(value.seconds)
    elseif type == TYPES.names.bool then
        buf:put_bool(value)
    end
end

local function get_value(buf, type)
    if type == TYPES.codes.null then
        return nil
    elseif type == TYPES.codes.int8 then
        local value = buf:get_byte()
        if value <= 127 then
            return value
        else
            return 127 - value
        end
    elseif type == TYPES.codes.int16 then
        return buf:get_sint16()
    elseif type == TYPES.codes.int32 then
        return buf:get_sint32()
    elseif type == TYPES.codes.int64 then
        return buf:get_int64()
    elseif type == TYPES.codes.uint8 then
        return buf:get_byte()
    elseif type == TYPES.codes.uint16 then
        return buf:get_uint16()
    elseif type == TYPES.codes.uint32 then
        return buf:get_uint32()
    elseif type == TYPES.codes.string then
        return buf:get_string()
    elseif type == TYPES.codes.norm8 then
        return buf:get_norm8()
    elseif type == TYPES.codes.norm16 then
        return buf:get_norm16()
    elseif type == TYPES.codes.float32 then
        return buf:get_float32()
    elseif type == TYPES.codes.float64 then
        return buf:get_float64()
    elseif type == TYPES.codes.timestamp then
        return { seconds = buf:get_int64() }
    elseif type == TYPES.codes.bool then
        return buf:get_bool()
    end
end

local function has_null(row, keys)
    for i=1, #keys do
        local annotation = keys[i]
        local value = row[annotation[1]]
        if value == nil then
            return true
        end
    end

    return false
end

local function encode_table(buf, array, keys)
    for _, row in ipairs(array) do
        local if_null = has_null(row, keys)
        buf:put_bool(if_null)
        for i=1, #keys do
            local annotation = keys[i]
            local type = annotation[2]
            local value = row[annotation[1]]
            if if_null then
                if value ~= nil then
                    buf:put_byte(TYPES.codes[type])
                else
                    buf:put_byte(TYPES.codes.null)
                    goto continue
                end
            end
            put_value(buf, value, type)
            ::continue::
        end
    end
end

local function decode_table(buf, size, keys)
    local tbl = {}
    for _=1, size do
        local row = {}
        local if_null = buf:get_bool()
        for i=1, #keys do
            local annotation = keys[i]
            local key = annotation[1]
            local type = annotation[2]
            if not if_null then
                row[key] = get_value(buf, type)
            else
                type = buf:get_byte()
                row[key] = get_value(buf, type)
            end
        end
        table.insert(tbl, row)
    end

    return tbl
end

-- local keys = {
--     {"key", "uint8"}
-- }

function module.encode(buf, array, annotation, primary_key)
    buf:put_byte(VERSION)
    buf:put_byte(#annotation)
    local keys = {}

    for i, key in ipairs(annotation) do
        keys[key[1]] = {i, key[2]}
        table.insert(keys, key)

        buf:put_string(key[1])
        buf:put_byte(TYPES.codes[key[2]])
    end

    buf:put_string(primary_key)
    put_value(buf, #array, TYPES.names[keys[primary_key][2]])

    encode_table(buf, array, keys)
end

function module.decode(buf)
    local version = buf:get_byte(VERSION)

    if version ~= 0 then
        return
    end

    local annotation_size = buf:get_byte()
    local keys = {}
    for i=1, annotation_size do
        local key = buf:get_string()
        local key_type = buf:get_byte()

        table.insert(keys, {key, key_type})
        keys[key] = {i, key_type}
    end

    local primary_key = buf:get_string()
    local size_type = keys[primary_key][2]

    local size = get_value(buf, size_type)
    return decode_table(buf, size, keys)
end

function module.serialize(array, annotation, primary_key)
    local buf = db:new()
    module.encode(buf, array, annotation, primary_key)

    return buf:get_bytes()
end

function module.deserialize(bytes)
    local buf = db:new(bytes)
    return module.decode(buf)
end

return module
