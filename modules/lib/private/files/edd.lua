local bson = require "lib/private/files/bson"

local module = {}

-- ... (keep all your existing constants and type definitions)

local function __get_num(buf)
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
    end
    
    return 0
end

local function __get_item(buf)
    local item_type = buf:get_uint(4)
    
    if item_type == TYPES.bool then
        return buf:get_bit()
    elseif item_type == TYPES.string then
        return buf:get_string()
    elseif item_type == TYPES.table then
        return bson.decode_array(buf)
    else -- all number types
        return __get_num(buf)
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
    
    -- Reconstruct matrix from quaternion (implementation depends on your math library)
    local mat = quat.to_mat4(quaternion)
    
    -- Apply signs if needed (implementation depends on your specific needs)
    for i = 1, 16 do
        if not signs[i] then
            mat[i] = -math.abs(mat[i])
        else
            mat[i] = math.abs(mat[i])
        end
    end
    
    return mat
end

local function __get_standart(buf, has_standart)
    if not has_standart then return nil end
    
    local standart = {}
    local has_rot = buf:get_bit()
    local has_pos = buf:get_bit()
    local has_size = buf:get_bit()
    local has_body = buf:get_bit()
    
    if has_rot then standart.tsf_rot = __decode_rot(buf) end
    if has_pos then standart.tsf_pos = __decode_vec(buf) end
    if has_size then standart.tsf_size = __decode_vec(buf) end
    if has_body then standart.body_size = __decode_vec(buf) end
    
    return standart
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

function module.decode(buf)
    local dirty = {}
    
    local has_standart = buf:get_bit()
    local has_custom = buf:get_bit()
    local has_textures = buf:get_bit()
    local has_models = buf:get_bit()
    local has_components = buf:get_bit()
    
    dirty.standart_fields = __get_standart(buf, has_standart)
    dirty.custom_fields = __get_custom(buf, has_custom)
    dirty.textures = __get_textures(buf, has_textures)
    dirty.models = __get_models(buf, has_models)
    dirty.components = __get_components(buf, has_components)
    
    return dirty
end

return module