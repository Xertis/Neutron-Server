local bb = require "lib/public/bit_buffer"



local MAX_UINT16 = 65535
local MIN_UINT16 = 0
local MAX_UINT32 = 4294967295
local MIN_UINT32 = 0
local MAX_UINT64 = 18446744073709551615
local MIN_UINT64 = 0

local MAX_BYTE = 255

local MAX_INT16 = 32767
local MIN_INT16 = -32768
local MAX_INT32 = 2147483647
local MIN_INT32 = -2147483648
local MAX_INT64 = 9223372036854775807
local MIN_INT64 = -9223372036854775808

local bson = {}
local module = {}

TYPES_ARRAY = { "byte", "uint16", "uint32", "int16", "int32", "int64", "float32", "float64", "bool", "string", "hashmap", "array", "table" }
TYPES_STRUCTURE = {
    byte = 1,
    uint16 = 2,
    uint32 = 3,
    int16 = 4,
    int32 = 5,
    int64 = 6,
    float32 = 7,
    float64 = 8,
    bool = 9,
    string = 10,
    hashmap = 11,
    array = 12,
    table = 13
}

KEYS_TYPES = {
    index = false,
    key = true,
}

function module.return_type_number(num)
    if num < 0 then
        if num >= MIN_INT16 then
            return TYPES_STRUCTURE.int16
        elseif num >= MIN_INT32 then
            return TYPES_STRUCTURE.int32
        elseif num >= MIN_INT64 then
            return TYPES_STRUCTURE.int64
        end
    else
        if num <= MAX_BYTE then
            return TYPES_STRUCTURE.byte
        elseif num <= MAX_UINT16 then
            return TYPES_STRUCTURE.uint16
        elseif num <= MAX_UINT32 then
            return TYPES_STRUCTURE.uint32
        elseif num <= MAX_INT64 then
            return TYPES_STRUCTURE.int64
        end
    end
end

function module.put_num(buf, num)
    local item_type = module.return_type_number(num)
    buf:put_uint(item_type, 4)

    if item_type == TYPES_STRUCTURE.int16 then
        buf:put_sint16(num)
    elseif item_type == TYPES_STRUCTURE.int32 then
        buf:put_sint32(num)
    elseif item_type == TYPES_STRUCTURE.int64 then
        buf:put_int64(num)
    elseif item_type == TYPES_STRUCTURE.byte then
        buf:put_byte(num)
    elseif item_type == TYPES_STRUCTURE.uint16 then
        buf:put_uint16(num)
    elseif item_type == TYPES_STRUCTURE.uint32 then
        buf:put_uint32(num)
    end
end

function module.put_float(buf, num)
    local decimal_places = string.len(tostring(num) - string.len(tostring(math.floor(num))) - 1)

    if decimal_places <= 7 then
        buf:put_uint(TYPES_STRUCTURE.float32, 4)
        buf:put_float32(num)
    else
        buf:put_uint(TYPES_STRUCTURE.float64, 4)
        buf:put_float64(num)
    end
end

function module.put_item(buf, item)
    if type(item) == 'string' then
        buf:put_uint(TYPES_STRUCTURE.string, 4)
        buf:put_string(item)
    elseif type(item) == 'boolean' then
        buf:put_uint(TYPES_STRUCTURE.bool, 4)
        buf:put_bit(item)
    elseif type(item) == 'number' and item % 1 == 0 then
        module.put_num(buf, item)
    elseif type(item) == 'number' and item % 1 ~= 0 then
        module.put_float(buf, item)
    elseif type(item) == 'table' then
        module.encode_array(buf, item)
    end
end

function module.get_item(buf)
    local type_item = buf:get_uint(4)
    if type_item == TYPES_STRUCTURE.string then
        return buf:get_string()
    elseif type_item == TYPES_STRUCTURE.byte then
        return buf:get_byte()
    elseif type_item == TYPES_STRUCTURE.bool then
        return buf:get_bit()
    elseif type_item == TYPES_STRUCTURE.int16 then
        return buf:get_sint16()
    elseif type_item == TYPES_STRUCTURE.int32 then
        return buf:get_sint32()
    elseif type_item == TYPES_STRUCTURE.int64 then
        return buf:get_int64()
    elseif type_item == TYPES_STRUCTURE.uint16 then
        return buf:get_uint16()
    elseif type_item == TYPES_STRUCTURE.uint32 then
        return buf:get_uint32()
    elseif type_item == TYPES_STRUCTURE.float32 then
        return buf:get_float32()
    elseif type_item == TYPES_STRUCTURE.float64 then
        return buf:get_float64()
    else
        return module.decode_array(buf)
    end
end

function module.decode_array(buf)
    local len = buf:get_uint32()
    local res = {}
    for i = 1, len do
        local type_item = buf:get_bit()
        if type_item == KEYS_TYPES.index then
            table.insert(res, module.get_item(buf))
        else
            local key = buf:get_string()
            res[key] = module.get_item(buf)
        end
    end
    return res
end

function module.get_len_table(arr)
    local count = 0
    for i, b in pairs(arr) do
        count = count + 1
    end
    return count
end

function module.encode_array(buf, arr)
    buf:put_uint(TYPES_STRUCTURE.table, 4)
    buf:put_uint32(module.get_len_table(arr))
    for i, item in pairs(arr) do
        if type(i) == 'number' then
            buf:put_bit(KEYS_TYPES.index)
            module.put_item(buf, item)
        else
            buf:put_bit(KEYS_TYPES.key)
            buf:put_string(i)
            module.put_item(buf, item)
        end
    end
end

function bson.encode(buf, array)
    module.encode_array(buf, array)
end

function bson.decode(buf)
    local is_tbl = buf:get_uint(4)
    local data = module.decode_array(buf)
    return data
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