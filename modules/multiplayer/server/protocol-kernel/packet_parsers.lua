local module = {}

-- & - буффер
-- $ - аргумент
-- % - добавочный аргумент

local DATA_ENCODE = {
    ["boolean"] = function(buffer, value)
        value = value and true or false

        buffer:put_bool(value)
    end,
    ["var"] = function (buffer, value)
        buffer:put_bytes(bincode.encode_varint(value))
    end,
    ["any"] = function (buffer, value)
        return buffer:put_any(value)
    end,
    ["player_pos"] = function(buffer, value)
        local x, y, z = unpack(value)
        y = math.clamp(y, 0, 262)

        x = (x - (x - x % 32) ) * 1000 + 0.5
        y = math.floor(y * 1000 + 0.5)
        z = (z - (z - z % 32) ) * 1000 + 0.5

        local y_low = bit.band(y, 0x1FF)
        local y_high = bit.rshift(y, 9)

        buffer:put_uint24(bit.bor(bit.lshift(y_low, 15), x))
        buffer:put_uint24(bit.bor(bit.lshift(z, 9), y_high))
    end,
    ["bson"] = function (buffer, value)
        bson.encode(buffer, value)
    end,
    ["int8"] = function(buffer, value)
        if value > MAX_INT8 or value < MIN_INT8 then
            logger.log(string.format("Out of range for int8: %s", value), 'E', true)
            value = math.clamp(value, MIN_INT8, MAX_INT8)
        end

        buffer:put_byte(value + 127)
    end,
    ["uint8"] = function(buffer, value)
        if value > MAX_BYTE or value < MIN_BYTE then
            logger.log(string.format("Out of range for uint8: %s", value), 'E', true)
            value = math.clamp(value, MIN_BYTE, MAX_BYTE)
        end

        buffer:put_byte(value)
    end,
    ["int16"] = function(buffer, value)
        if value > MAX_INT16 or value < MIN_INT16 then
            logger.log(string.format("Out of range for int16: %s", value), 'E', true)
            value = math.clamp(value, MIN_INT16, MAX_INT16)
        end

        buffer:put_sint16(value)
    end,
    ["uint16"] = function(buffer, value)
        if value > MAX_UINT16 or value < MIN_UINT16 then
            logger.log(string.format("Out of range for uint16: %s", value), 'E', true)
            value = math.clamp(value, MIN_UINT16, MAX_UINT16)
        end

        buffer:put_uint16(value)
    end,
    ["int32"] = function(buffer, value)
        if value > MAX_INT32 or value < MIN_INT32 then
            logger.log(string.format("Out of range for int32: %s", value), 'E', true)
            value = math.clamp(value, MIN_INT32, MAX_INT32)
        end

        buffer:put_sint32(value)
    end,
    ["degree"] = function(buffer, value)
        local deg = math.clamp(value, -180, 180)

        local normalized = (deg + 180) / 360

        buffer:put_uint24(math.floor(normalized * 16777215 + 0.5))
    end,
    ["uint32"] = function(buffer, value)
        if value > MAX_UINT32 or value < MIN_UINT32 then
            logger.log(string.format("Out of range for uint32: %s", value), 'E', true)
            value = math.clamp(value, MIN_UINT32, MAX_UINT32)
        end

        buffer:put_uint32(value)
    end,
    ["int64"] = function(buffer, value)
        if value > MAX_INT64 or value < MIN_INT64 then
            logger.log(string.format("Out of range for int32: %s", value), 'E', true)
            value = math.clamp(value, MIN_INT64, MAX_INT64)
        end

        buffer:put_int64(value)
    end,
    ["f32"] = function(buffer, value)
        buffer:put_float32(value)
    end,
    ["f64"] = function(buffer, value)
        buffer:put_float64(value)
    end,
    ["string"] = function(buffer, value)
        buffer:put_string(value)
    end
}

local DATA_DECODE = {
    ["boolean"] = function(buffer)
        return buffer:get_bool()
    end,
    ["var"] = function (buffer)
        return bincode.decode_varint(buffer)
    end,
    ["any"] = function (buffer)
        return buffer:get_any()
    end,
    ["player_pos"] = function(buffer)
        local i1 = buffer:get_uint24()
        local i2 = buffer:get_uint24()

        local x = bit.band(i1, 0x7FFF)

        local y_low = bit.rshift(i1, 15)
        local y_high = bit.band(i2, 0x1FF)
        local y = bit.bor(bit.lshift(y_high, 9), y_low)

        local z = bit.rshift(i2, 9)

        return {x = x / 1000, y = y / 1000, z = z / 1000}
    end,
    ["bson"] = function (buffer)
        return bson.decode(buffer)
    end,
    ["int8"] = function(buffer)
        return buffer:get_byte() - 127
    end,
    ["uint8"] = function(buffer)
        return buffer:get_byte()
    end,
    ["int16"] = function(buffer)
        return buffer:get_sint16()
    end,
    ["uint16"] = function(buffer)
        return buffer:get_uint16()
    end,
    ["int32"] = function(buffer)
        return buffer:get_sint32()
    end,
    ["degree"] = function(buffer)
        local deg = buffer:get_uint24()
        return (deg / 16777215) * 360 - 180
    end,
    ["uint32"] = function(buffer)
        return buffer:get_uint32()
    end,
    ["int64"] = function(buffer)
        return buffer:get_int64()
    end,
    ["f32"] = function(buffer)
        return buffer:get_float32()
    end, -- алиас для float
    ["f64"] = function(buffer)
        return buffer:get_float64()
    end, -- алиас для double
    ["string"] = function(buffer)
        return buffer:get_string()
    end
}

local function is_array(spec)
    if spec[1] == '&' then
        return true, string.sub(spec, 2)
    else
        return false, spec
    end
end

local function get_type(spec)
    local arg_name, arg_type = unpack(string.explode(':', spec))
    return arg_name, arg_type
end

function module.build_packet(client_or_server, packet_type, ...)
    local data = {}
    local buffer = protocol.create_databuffer()
end