-- Entity Dirty Data
local bson = require "lib/private/files/bson"
local module = {}

local function put_degree(buffer, value)
    local deg = math.clamp(value, -180, 180)

    local normalized = (deg + 180) / 360

    buffer:put_uint24(math.floor(normalized * 16777215 + 0.5))
end

local function encode_standart_fields(buf, fields)
    --Кладём поворот
    for _, axis in ipairs(fields.tsf_rot) do
        put_degree(buf, axis)
    end

    --Кладём позицию
    for _, axis in ipairs(fields.tsf_pos) do
        buf:put_float64(axis)
    end

    --Кладём размер
    for _, axis in ipairs(fields.tsf_size) do
        buf:put_uint24(math.floor((axis + 838) * 10000 + 0.5))
    end

    --Кладём хитбокс
    for _, axis in ipairs(fields.body_size) do
        buf:put_uint24(math.floor((axis + 838) * 10000 + 0.5))
    end
end

local function encode_textures(buf, fields)
    for key, val in pairs(fields) do
        buf:put_string(key)
        buf:put_string(val)
    end
end

local function encode_models(buf, fields)
    for key, val in pairs(fields) do
        if type(key) == "number" then

        buf:put_sint16(key)
        buf:put_string(val)

        end
    end
end

local function encode_components(buf, fields)
    for comp, is_active in pairs(fields) do
        buf:put_string(comp)
        buf:put_bool(is_active)
    end
end

function module.encode(buf, dirty)
    encode_standart_fields(buf, dirty.standart_fields or {})
    bson.encode(buf, dirty.custom_fields or {})

    encode_textures(buf, dirty.textures or {})
    encode_models(buf, dirty.models or {})
    encode_components(buf, dirty.components or {})
end

--------------------------------------------------

local function get_degree(buf)
    local normalized = buf:get_uint24() / 16777215
    return normalized * 360 - 180
end

local function decode_standard_fields(buf)
    local fields = {}

    fields.tsf_rot = {
        get_degree(buf),
        get_degree(buf),
        get_degree(buf)
    }

    fields.tsf_pos = {
        buf:get_float64(),
        buf:get_float64(),
        buf:get_float64()
    }

    fields.tsf_size = {
        buf:get_uint24() / 10000 - 838,
        buf:get_uint24() / 10000 - 838,
        buf:get_uint24() / 10000 - 838
    }

    fields.body_size = {
        buf:get_uint24() / 10000 - 838,
        buf:get_uint24() / 10000 - 838,
        buf:get_uint24() / 10000 - 838
    }

    return fields
end

local function decode_textures(buf)
    local textures = {}
    while buf:remaining() > 0 do
        local key = buf:get_string()
        local value = buf:get_string()
        textures[key] = value
    end
    return textures
end

local function decode_models(buf)
    local models = {}
    while buf:remaining() > 0 do
        local key = buf:get_sint16()
        local value = buf:get_string()
        models[key] = value
    end
    return models
end

local function decode_components(buf)
    local components = {}
    while buf:remaining() > 0 do
        local comp = buf:get_string()
        local is_active = buf:get_bool()
        components[comp] = is_active
    end
    return components
end

function module.decode(buf)
    local dirty = {}

    dirty.standart_fields = decode_standard_fields(buf)
    dirty.custom_fields = bson.decode(buf)

    dirty.textures = decode_textures(buf)
    dirty.models = decode_models(buf)
    dirty.components = decode_components(buf)

    return dirty
end

return module
