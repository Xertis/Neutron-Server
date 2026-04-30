local bit_buffer =
{
    __call =
        function(bit_buffer, ...)
            return bit_buffer:new(...)
        end
}

local MAX_UINT16 = 65535
local MIN_UINT16 = 0
local MAX_UINT24 = 16777215
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

local TYPES = {
    null    = 0,
    int8    = 1,
    int16   = 2,
    int32   = 3,
    int64   = 4,
    uint8   = 5,
    uint16  = 6,
    uint24  = 7,
    uint32  = 8,
    string  = 9,
    norm8   = 10,
    norm16  = 11,
    float32 = 12,
    float64 = 13,
    bool    = 14
}

local STANDARD_TYPES = {
    b = 1,
    B = 1,
    h = 2,
    H = 2,
    i = 4,
    I = 4,
    l = 8,
    L = 8,
    f = 4,
    d = 8,
    ['?'] = 1
}

local putExp = bit.compile("a | b << c")
local getExp = bit.compile("a & 1 << b")

function bit_buffer:new(bytes, order)
    local obj = setmetatable({},
        {
            __index = function(buf, key)
                local v = rawget(buf, key)

                if v ~= nil then
                    return v
                end
                return bit_buffer[key]
            end
        }
    )

    obj.pos = 1
    obj.current = 0
    obj.current_is_zero = true
    obj.external_buffer = false
    obj.recv_func = false
    obj.order = order or "BE"

    if type(bytes) ~= "cdata" then
        obj.bytes = Bytearray()
        obj.bytes:append(bytes or {})
    else
        obj.bytes = bytes
    end

    return obj
end

function bit_buffer:set_order(order)
    self.order = order
end

function bit_buffer:swap16(num)
    if self.order == "LE" then
        return num
    else
        return bit.rshift(bit.bswap(num), 16)
    end
end

function bit_buffer:swap24(num)
    if self.order == "LE" then
        return num
    else
        return bit.rshift(bit.bswap(num), 8)
    end
end

function bit_buffer:swap32(num)
    if self.order == "LE" then
        return num
    else
        return bit.bswap(num)
    end
end

function bit_buffer:swap_bytes(bytes)
    if self.order == "LE" then
        return bytes
    else
        local res = Bytearray(#bytes)

        for i = 1, #bytes do
            res[#bytes - (i - 1)] = bytes[i]
        end

        return res
    end
end

function bit_buffer:pack(value_type, num)
    local order = (self.order == "LE" and "<" or ">")
    local bytes = byteutil.pack(order .. value_type, num)
    self:put_bytes(bytes)
end

function bit_buffer:unpack(value_type)
    local bytes = self:get_bytes(STANDARD_TYPES[value_type])
    local order = (self.order == "LE" and "<" or ">")
    return byteutil.unpack(order .. value_type, bytes)
end

function bit_buffer:put_bit(bit)
    self.current = putExp(self.current, bit and 1 or 0, (self.pos - 1) % 8)

    if self.pos % 8 == 0 then
        self.bytes:append(self.current)
        self.current_is_zero = true
        self.current = 0
    else
        self.current_is_zero = false
    end

    self.pos = self.pos + 1
end

function bit_buffer:get_bit()
    local byte_index = math.ceil(self.pos / 8)
    local byte = nil

    if not self.external_buffer then
        byte = self.bytes[byte_index]

        if byte == nil and not self.current_is_zero then
            byte = self.current
        end
    else
        byte = self.bytes[byte_index]
        if byte == nil then
            byte = self.recv_func(self.external_buffer, byte_index)
            if not byte then
                coroutine.yield()
                return self:get_bit()
            end
        end
    end

    local bit_pos = (self.pos - 1) % 8
    local bit = getExp(byte, bit_pos) ~= 0
    self.pos = self.pos + 1
    return bit
end

function bit_buffer:__get_byte(idx)
    local bytes = self.bytes
    local byte = nil
    if self.external_buffer then
        byte = self.recv_func(self.external_buffer, idx)
        while not byte do
            coroutine.yield()
            byte = self.recv_func(self.external_buffer, idx)
        end
    else
        byte = bytes[idx]
    end

    return byte
end

function bit_buffer:__get_bytes(idx, count)
    local bytes = Bytearray()

    for i = idx, idx + count - 1 do
        bytes:append(self:__get_byte(i))
    end

    return bytes
end

function bit_buffer:get_uint(width)
    if width % 8 == 0 then
        local size = width / 8
        local bits_offset = (self.pos - 1) % 8
        local pos = self.pos
        local num = 0

        if bits_offset == 0 then
            for i = 0, size - 1 do
                local idx = math.ceil((pos + i * 8) / 8)
                local byte = self:__get_byte(idx)
                num = num + byte * (256 ^ i)
            end
        else
            local bytes = self:__get_bytes(math.ceil(pos / 8), size + 1)
            for i = 1, size + 1 do
                num = num + bytes[i] * (256 ^ (i - 1))
            end

            num = bit.band(bit.rshift(num, bits_offset), bit.lshift(1, width) - 1)
        end

        self.pos = pos + width
        return num
    end

    local num = 0
    for i = 1, width do
        num = putExp(num, self:get_bit() and 1 or 0, i - 1)
    end
    return num
end

function bit_buffer:put_uint(num, width)
    if width % 8 == 0 and (self.pos - 1) % 8 == 0 then
        for i = 0, width / 8 - 1 do
            self.bytes:append(math.floor(num / (256 ^ i)) % 256)
        end
        self.pos = self.pos + width
        return
    end

    for i = 1, width do
        self:put_bit(getExp(num, i - 1) ~= 0)
    end
end

function bit_buffer:get_position()
    return self.pos
end

function bit_buffer:set_position(pos)
    self.pos = pos
end

function bit_buffer:move_position(step)
    self.pos = self.pos + step
end

function bit_buffer:next()
    self.pos = math.ceil((self.pos - 1) / 8) * 8 + 1
end

function bit_buffer:reset()
    self.pos = 1
end

function bit_buffer:size()
    return math.floor(self.pos / 8)
end

function bit_buffer:put_bytes(bytes)
    for i = 1, #bytes do
        self:put_uint(bytes[i], 8)
    end
end

function bit_buffer:flush()
    if not self.current_is_zero then
        self.bytes:append(self.current)
        self.current = 0
        self.current_is_zero = true

        self.pos = 8 - (self.pos % 8 + 1) + self.pos
    end
end

function bit_buffer:get_bytes(count)
    if not count then
        local bs = Bytearray()

        bs:append(self.bytes)
        if not self.current_is_zero then
            bs:append(self.current)
        end

        return bs
    else
        local bytes = Bytearray()

        for _ = 1, count do
            bytes:append(self:get_uint(8))
        end

        return bytes
    end
end

function bit_buffer:set_bytes(bytes)
    if type(bytes) == 'table' then
        self.bytes = Bytearray(bytes)
    else
        self.bytes = bytes
    end
end

function bit_buffer:put_byte(byte)
    self:put_uint(byte, 8)
end

function bit_buffer:put_norm8(single)
    self:put_uint(math.floor((single + 1) * 127.5 + 0.5), 8)
end

function bit_buffer:put_norm16(double)
    local uint16 = nil
    if double >= 0 then
        uint16 = math.floor(double * 32767 + 32767 + 0.5)
    else
        uint16 = math.floor((double + 1) * 32767 + 0.5)
    end

    self:put_uint(self:swap16(uint16), 16)
end

function bit_buffer:put_string(str)
    local bytes = utf8.tobytes(str)
    self:put_bytes(self:swap_bytes(bytes))
    self:put_uint(255, 8)
end

function bit_buffer:put_uint24(num)
    self:put_uint(self:swap24(num), 24)
end

function bit_buffer:put_int24(num)
    self:put_uint(self:swap24(bit.band(num, 0xFFFFFF)), 24)
end

function bit_buffer:put_float16(val)
    local sign = 0
    if val < 0 then
        sign = 1
        val = -val
    end
    local mantissa, exponent = 0, 0
    if val ~= 0 then
        local m, e = math.frexp(val)
        mantissa = (m * 2 - 1) * 1024.0
        exponent = e + 14
        if exponent < 1 then
            mantissa = math.floor(mantissa * math.ldexp(0.5, 1 - exponent) + 0.5)
            exponent = 0
        elseif exponent >= 31 then
            exponent = 31
            mantissa = 0
        else
            mantissa = math.floor(mantissa + 0.5)
            if mantissa >= 1024 then
                mantissa = 0
                exponent = exponent + 1
                if exponent >= 31 then exponent = 31 end
            end
        end
    end
    local byte0 = mantissa % 256
    local byte1 = math.floor(mantissa / 256) + (exponent % 32) * 4 + sign * 128

    if self.order ~= "LE" then
        self:put_uint(byte1, 8)
        self:put_uint(byte0, 8)
    else
        self:put_uint(byte0, 8)
        self:put_uint(byte1, 8)
    end
end

function bit_buffer:put_any(value)
    if type(value) == "boolean" then
        self:put_byte(TYPES.bool)
        self:put_bool(value)
    elseif type(value) == "string" then
        self:put_byte(TYPES.string)
        self:put_string(value)
    elseif type(value) == "nil" then
        self:put_byte(TYPES.null)
    elseif type(value) == "number" then
        if value ~= math.floor(value) then
            self:put_byte(TYPES.float64)
            self:put_float64(value)
        elseif value < 0 then
            if value >= MIN_INT16 then
                self:put_byte(TYPES.int16)
                self:put_int16(value)
            elseif value >= MIN_INT32 then
                self:put_byte(TYPES.int32)
                self:put_int32(value)
            elseif value >= MIN_INT64 then
                self:put_byte(TYPES.int64)
                self:put_int64(value)
            end
        elseif value >= 0 then
            if value <= MAX_BYTE then
                self:put_byte(TYPES.uint8)
                self:put_byte(value)
            elseif value <= MAX_UINT16 then
                self:put_byte(TYPES.uint16)
                self:put_uint16(value)
            elseif value <= MAX_UINT24 then
                self:put_byte(TYPES.uint24)
                self:put_uint24(value)
            elseif value <= MAX_UINT32 then
                self:put_byte(TYPES.uint32)
                self:put_uint32(value)
            elseif value <= MAX_INT64 then
                self:put_byte(TYPES.int64)
                self:put_int64(value)
            end
        end
    end
end

function bit_buffer:get_byte()
    return self:get_uint(8)
end

function bit_buffer:get_norm8()
    local byte = self:get_uint(8)
    return (byte / 127.5) - 1
end

function bit_buffer:get_norm16()
    local uint16 = self:swap16(self:get_uint(16))

    if uint16 > 32767 then
        return (uint16 - 32767) / 32767
    else
        return uint16 / 32767 - 1
    end
end

function bit_buffer:get_string()
    local bytes = Bytearray()

    while true do
        local byte = self:get_uint(8)
        if byte ~= 255 then
            bytes:append(byte)
        else
            break
        end
    end

    return utf8.tostring(self:swap_bytes(bytes))
end

function bit_buffer:get_uint24()
    return self:swap24(self:get_uint(24))
end

function bit_buffer:get_float16()
    local byte0, byte1
    if self.order ~= "LE" then
        byte1 = self:get_uint(8)
        byte0 = self:get_uint(8)
    else
        byte0 = self:get_uint(8)
        byte1 = self:get_uint(8)
    end

    local sign = math.floor(byte1 / 128)
    local exponent = math.floor((byte1 % 128) / 4)
    local mantissa = byte0 + (byte1 % 4) * 256

    if exponent == 0 then
        if mantissa == 0 then
            return sign == 1 and -0.0 or 0.0
        else
            return sign == 1
                and -math.ldexp(mantissa / 1024.0, -14)
                or math.ldexp(mantissa / 1024.0, -14)
        end
    elseif exponent == 31 then
        if mantissa == 0 then
            return sign == 1 and -math.huge or math.huge
        else
            return 0 / 0
        end
    else
        local m = 1 + mantissa / 1024.0
        if sign == 1 then m = -m end
        return math.ldexp(m, exponent - 15)
    end
end

function bit_buffer:get_any()
    local type_byte = self:get_byte()

    if type_byte == TYPES.bool then
        return self:get_bool()
    elseif type_byte == TYPES.string then
        return self:get_string()
    elseif type_byte == TYPES.null then
        return nil
    elseif type_byte == TYPES.float64 then
        return self:get_float64()
    elseif type_byte == TYPES.int16 then
        return self:get_int16()
    elseif type_byte == TYPES.int32 then
        return self:get_int32()
    elseif type_byte == TYPES.int64 then
        return self:get_int64()
    elseif type_byte == TYPES.uint8 then
        return self:get_byte()
    elseif type_byte == TYPES.uint16 then
        return self:get_uint16()
    elseif type_byte == TYPES.uint24 then
        return self:get_uint24()
    elseif type_byte == TYPES.uint32 then
        return self:get_uint32()
    else
        error("Unknown type byte: " .. tostring(type_byte))
    end
end

function bit_buffer:put_bool(val) self:pack("?", val) end

function bit_buffer:get_bool() return self:unpack("?") end

function bit_buffer:put_int8(num) self:pack("b", num) end

function bit_buffer:get_int8() return self:unpack("b") end

function bit_buffer:put_int16(num) self:pack("h", num) end

function bit_buffer:get_int16() return self:unpack("h") end

function bit_buffer:put_uint16(num) self:pack("H", num) end

function bit_buffer:get_uint16() return self:unpack("H") end

function bit_buffer:put_int32(num) self:pack("i", num) end

function bit_buffer:get_int32() return self:unpack("i") end

function bit_buffer:put_uint32(num) self:pack("I", num) end

function bit_buffer:get_uint32() return self:unpack("I") end

function bit_buffer:put_int64(num) self:pack("l", num) end

function bit_buffer:get_int64() return self:unpack("l") end

function bit_buffer:put_float32(num) self:pack("f", num) end

function bit_buffer:get_float32() return self:unpack("f") end

function bit_buffer:put_float64(num) self:pack("d", num) end

function bit_buffer:get_float64() return self:unpack("d") end

setmetatable(bit_buffer, bit_buffer)

return bit_buffer
