local bb = require "lib/public/bit_buffer"


local MAX_UINT16 = 65535
local MIN_UINT16 = 0
local MAX_UINT32 = 4294967295
local MIN_UINT32 = 0
local MAX_BYTE = 255

local MIN_NBYTE = -255
local MAX_NINT16 = 0
local MIN_NINT16 = -65535
local MAX_NINT32 = 0
local MIN_NINT32 = -4294967295

local MAX_INT64 = 9223372036854775807
local MIN_INT64 = -9223372036854775808

local bson = {}
local TYPES = {
    byte = 0,
    uint16 = 1,
    uint32 = 2,
    nbyte = 3,
    nint16 = 4,
    nint32 = 5,
    int64 = 6,
    float32 = 7,
    float64 = 8,
    bool = 9,
    string = 10,
    table = 11
}

local function __return_type_number(num)
    if num < 0 then
        if num >= MIN_NBYTE then
            return TYPES.nint8
        elseif num >= MIN_NINT16 then
            return TYPES.nint16
        elseif num >= MIN_NINT32 then
            return TYPES.nint32
        elseif num >= MIN_INT64 then
            return TYPES.int64
        end
    else
        if num <= MAX_BYTE then
            return TYPES.byte
        elseif num <= MAX_UINT16 then
            return TYPES.uint16
        elseif num <= MAX_UINT32 then
            return TYPES.uint32
        elseif num <= MAX_INT64 then
            return TYPES.int64
        end
    end
end

local function __return_type_float(num)
    local decimal_places = string.len(tostring(num) - string.len(tostring(math.floor(num))) - 1)

    if decimal_places > 7 then
        return TYPES.float64
    end

    return TYPES.float32
end

local function __put_num(buf, num)
    local item_type = nil
    if num % 1 == 0 then
        item_type = __return_type_number(num)
    else
        item_type = __return_type_float(num)
    end

    buf:put_uint(item_type, 4)

    if item_type == TYPES.float32 then
        buf:put_float32(num)
    elseif item_type == TYPES.float64 then
        buf:put_float64(num)
    elseif item_type == TYPES.byte then
        buf:put_byte(num)
    elseif item_type == TYPES.uint16 then
        buf:put_uint16(num)
    elseif item_type == TYPES.uint32 then
        buf:put_uint32(num)
    elseif item_type == TYPES.int64 then
        buf:put_int64(num)
    elseif item_type == TYPES.nbyte then
        buf:put_byte(math.abs(num))
    elseif item_type == TYPES.nint16 then
        buf:put_uint16(math.abs(num))
    elseif item_type == TYPES.nint32 then
        buf:put_uint32(math.abs(num))
    end
end

local function __put_item(buf, item)
    local item_type = type(item)
    if item_type == "number" then
        __put_num(buf, item)
    elseif item_type == "boolean" then
        buf:put_uint(TYPES.bool, 4)
        buf:put_bit(item)
    elseif item_type == "string" then
        buf:put_uint(TYPES.string, 4)
        buf:put_string(item)
    elseif item_type == "table" then
        buf:put_uint(TYPES.table, 4)
        bson.encode_array(buf, item)
    end
end

local function __pairs_len(arr)
    local count = 0
    local keys = {}
    for key, _ in pairs(arr) do
        if type(key) ~= "number" then
            count = count + 1
            table.insert(keys, key)
        end
    end
    return count, keys
end

local function __get_item(buf)
    local item_type = buf:get_uint(4)

    if item_type == TYPES.float32 then
        return buf:get_float32()
    elseif item_type == TYPES.float64 then
        return buf:get_float64()
    elseif item_type == TYPES.byte then
        return buf:get_byte()
    elseif item_type == TYPES.uint16 then
        return buf:get_uint16()
    elseif item_type == TYPES.uint32 then
        return buf:get_uint32()
    elseif item_type == TYPES.int64 then
        return buf:get_int64()
    elseif item_type == TYPES.nbyte then
        return -buf:get_byte()
    elseif item_type == TYPES.nint16 then
        return -buf:get_uint16()
    elseif item_type == TYPES.nint32 then
        return -buf:get_uint32()
    elseif item_type == TYPES.bool then
        return buf:get_bit()
    elseif item_type == TYPES.string then
        return buf:get_string()
    elseif item_type == TYPES.table then
        return bson.decode_array(buf)
    end
end

function bson.decode_array(buf)
    local array_length = buf:get_uint16()
    local hashmap_length = buf:get_uint16()

    local keys = {}
    for i = 1, hashmap_length do
        keys[i] = buf:get_string()
    end

    local arr = {}

    for i = 1, array_length do
        arr[i] = __get_item(buf)
    end

    for i = 1, hashmap_length do
        arr[keys[i]] = __get_item(buf)
    end

    return arr
end

function bson.encode_array(buf, arr)
    local array_length = #arr
    local hashmap_length, keys = __pairs_len(arr)

    buf:put_uint16(array_length)
    buf:put_uint16(hashmap_length)

    for _, key in ipairs(keys) do
        buf:put_string(key)
    end

    for i=1, array_length do
        __put_item(buf, arr[i])
    end

    for _, key in ipairs(keys) do
        __put_item(buf, arr[key])
    end
end

function bson.encode(buf, array)
    bson.encode_array(buf, array)
end

function bson.decode(buf)
    return bson.decode_array(buf)
end

function bson.serialize(array)
    local buf = bb:new()
    bson.encode(buf, array)
    buf:flush()

    return buf.bytes
end

function bson.deserialize(bytes)
    local buf = bb:new(bytes)
    return bson.decode(buf)
end

return bson