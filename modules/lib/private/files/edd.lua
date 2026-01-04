local bson = require "lib/private/files/bson"

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

local TYPES = {
    float32 = 1,
    float64 = 2,
    byte = 3,
    uint16 = 4,
    uint32 = 5,
    int64 = 6,
    nbyte = 7,
    nint16 = 8,
    nint32 = 9,
    bool = 10,
    string = 11,
    table = 12
}


local module = {}

local function __get_num(buf, item_type)
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
    end
end

local function __get_item(buf)
    local item_type = buf:get_uint(4)
    if item_type == TYPES.bool then
        return buf:get_bit()
    elseif item_type == TYPES.string then
        return buf:get_string()
    elseif item_type == TYPES.table then
        return bson.decode_array(buf)
    else
        return __get_num(buf, item_type)
    end
end

local function __decode_vec(buf)
    return {
        buf:get_float32(),
        buf:get_float32(),
        buf:get_float32()
    }
end

local function __decode_rot(buf)
    local signs = {}
    for i = 1, 16 do
        signs[i] = buf:get_bit()
    end
    local quaternion = {
        buf:get_float32(),
        buf:get_float32(),
        buf:get_float32(),
        buf:get_float32()
    }
    local mat = mat4.from_quat(quaternion)
    for i = 1, 16 do
        if not signs[i] then
            mat[i] = -math.abs(mat[i])
        else
            mat[i] = math.abs(mat[i])
        end
    end
    return mat
end

local function __get_standard(buf, has_standard)
    if not has_standard then return nil end
    local standard = {}
    local has_rot = buf:get_bit()
    local has_pos = buf:get_bit()
    local has_size = buf:get_bit()
    local has_body = buf:get_bit()
    if has_rot then standard.tsf_rot = __decode_rot(buf) end
    if has_pos then standard.tsf_pos = __decode_vec(buf) end
    if has_size then standard.tsf_size = __decode_vec(buf) end
    if has_body then standard.body_size = __decode_vec(buf) end
    return standard
end

local function __get_custom(buf, has_custom)
    if not has_custom then return nil end
    local custom = {}
    local count = buf:get_byte()
    for _ = 1, count do
        local key = buf:get_string()
        custom[key] = __get_item(buf)
    end
    return custom
end

local function __get_textures(buf, has_textures)
    if not has_textures then return nil end
    local textures = {}
    local count = buf:get_byte()
    for _ = 1, count do
        local key = buf:get_string()
        textures[key] = buf:get_string()
    end
    return textures
end

local function __get_models(buf, has_models)
    if not has_models then return nil end
    local models = {}
    local count = buf:get_byte()
    for _ = 1, count do
        local key = buf:get_byte()
        models[key] = buf:get_string()
    end
    return models
end

local function __get_components(buf, has_components)
    if not has_components then return nil end
    local components = {}
    local count = buf:get_byte()
    for _ = 1, count do
        local key = buf:get_string()
        components[key] = buf:get_bit()
    end
    return components
end

local function __encode_num(buf, num)
    if math.floor(num) == num then
        if num >= 0 then
            if num <= MAX_BYTE then
                buf:put_uint(TYPES.byte, 4)
                buf:put_byte(num)
            elseif num <= MAX_UINT16 then
                buf:put_uint(TYPES.uint16, 4)
                buf:put_uint16(num)
            elseif num <= MAX_UINT32 then
                buf:put_uint(TYPES.uint32, 4)
                buf:put_uint32(num)
            else
                buf:put_uint(TYPES.int64, 4)
                buf:put_int64(num)
            end
        else
            local abs_num = math.abs(num)
            if abs_num <= MAX_BYTE then
                buf:put_uint(TYPES.nbyte, 4)
                buf:put_byte(abs_num)
            elseif abs_num <= MAX_UINT16 then
                buf:put_uint(TYPES.nint16, 4)
                buf:put_uint16(abs_num)
            elseif abs_num <= MAX_UINT32 then
                buf:put_uint(TYPES.nint32, 4)
                buf:put_uint32(abs_num)
            else
                buf:put_uint(TYPES.int64, 4)
                buf:put_int64(num)
            end
        end
    else
        if math.abs(num) <= 3.4028235e38 and math.abs(num) >= 1.17549435e-38 then
            buf:put_uint(TYPES.float32, 4)
            buf:put_float32(num)
        else
            buf:put_uint(TYPES.float64, 4)
            buf:put_float64(num)
        end
    end
end

local function __encode_item(buf, item)
    local t = type(item)
    if t == "boolean" then
        buf:put_uint(TYPES.bool, 4)
        buf:put_bit(item)
    elseif t == "string" then
        buf:put_uint(TYPES.string, 4)
        buf:put_string(item)
    elseif t == "table" then
        buf:put_uint(TYPES.table, 4)
        bson.encode_array(buf, item)
    elseif t == "number" then
        __encode_num(buf, item)
    end
end

local function __encode_vec(buf, vec)
    buf:put_float32(vec[1])
    buf:put_float32(vec[2])
    buf:put_float32(vec[3])
end

local function __encode_rot(buf, rot)
    local quaternion = quat.from_mat4(rot)
    for i = 1, 16 do
        buf:put_bit(rot[i] >= 0)
    end
    buf:put_float32(quaternion[1])
    buf:put_float32(quaternion[2])
    buf:put_float32(quaternion[3])
    buf:put_float32(quaternion[4])
end

local function __encode_standard(buf, standard)
    local has_rot = standard.tsf_rot ~= nil
    local has_pos = standard.tsf_pos ~= nil
    local has_size = standard.tsf_size ~= nil
    local has_body = standard.body_size ~= nil
    buf:put_bit(has_rot)
    buf:put_bit(has_pos)
    buf:put_bit(has_size)
    buf:put_bit(has_body)
    if has_rot then __encode_rot(buf, standard.tsf_rot) end
    if has_pos then __encode_vec(buf, standard.tsf_pos) end
    if has_size then __encode_vec(buf, standard.tsf_size) end
    if has_body then __encode_vec(buf, standard.body_size) end
end

local function __encode_custom(buf, custom)
    local count = table.count_pairs(custom)
    buf:put_byte(count)
    for key, val in pairs(custom) do
        buf:put_string(key)
        __encode_item(buf, val)
    end
end

local function __encode_textures(buf, textures)
    local count = table.count_pairs(textures)
    buf:put_byte(count)
    for key, val in pairs(textures) do
        buf:put_string(key)
        buf:put_string(val)
    end
end

local function __encode_models(buf, models)
    local count = table.count_pairs(models)
    buf:put_byte(count)
    for key, val in pairs(models) do
        buf:put_byte(tonumber(key))
        buf:put_string(val)
    end
end

local function __encode_components(buf, components)
    local count = table.count_pairs(components)
    buf:put_byte(count)
    for key, val in pairs(components) do
        buf:put_string(key)
        buf:put_bit(val)
    end
end

function module.decode(buf)
    local dirty = {}
    local has_standard = buf:get_bit()
    local has_custom = buf:get_bit()
    local has_textures = buf:get_bit()
    local has_models = buf:get_bit()
    local has_components = buf:get_bit()
    dirty.standard_fields = __get_standard(buf, has_standard)
    dirty.custom_fields = __get_custom(buf, has_custom)
    dirty.textures = __get_textures(buf, has_textures)
    dirty.models = __get_models(buf, has_models)
    dirty.components = __get_components(buf, has_components)
    return dirty
end

function module.encode(buf, dirty)
    local has_standard = dirty.standard_fields ~= nil
    local has_custom = dirty.custom_fields ~= nil
    local has_textures = dirty.textures ~= nil
    local has_models = dirty.models ~= nil
    local has_components = dirty.components ~= nil
    buf:put_bit(has_standard)
    buf:put_bit(has_custom)
    buf:put_bit(has_textures)
    buf:put_bit(has_models)
    buf:put_bit(has_components)
    if has_standard then __encode_standard(buf, dirty.standard_fields) end
    if has_custom then __encode_custom(buf, dirty.custom_fields) end
    if has_textures then __encode_textures(buf, dirty.textures) end
    if has_models then __encode_models(buf, dirty.models) end
    if has_components then __encode_components(buf, dirty.components) end
end

return module