local bit_converter = require "lib/public/common/bit_converter"

-- Data buffer

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

local STANDART_TYPES = {
    b = 1,
    B = 1,
    h = 2,
    H = 2,
    i = 4,
    I = 4,
    l = 8,
    L = 8,
    ['?'] = 1
}

local TYPES = {
	null       = 0,
	int8       = 1,
	int16      = 2,
	int32      = 3,
	int64      = 4,
	uint8      = 5,
	uint16     = 6,
	uint24 	   = 7,
	uint32     = 8,
	string     = 9,
	norm8      = 10,
	norm16     = 11,
	float32    = 12,
	float64    = 13,
	bool       = 14
}

local data_buffer =
{
	__call =
	function(data_buffer, ...)
		return data_buffer:new(...)
	end
}

function data_buffer:new(bytes, order, useBytearray, co)
	bytes = bytes or { }

	if order then bit_converter.validate_order(order)
	else order = bit_converter.default_order end

    local obj = {
        pos = 1,
        order = order,
        useBytearray = useBytearray or false,
        bytes = useBytearray and Bytearray(bytes) or bytes,
		co = co
    }

    self.__index = self
    setmetatable(obj, self)

    return obj
end

local function rep_order(order)
	if order == "BE" then
		return ">"
	end

	return "<"
end

function data_buffer:pack(format, ...)
	self:put_bytes(byteutil.tpack(rep_order(self.order) .. format, ...))
end

function data_buffer:unpack(format)
	return byteutil.unpack(rep_order(self.order) .. format, self:get_bytes(STANDART_TYPES[format]))
end

function data_buffer:set_order(order)
	bit_converter.validate_order(order)

	self.order = order
	self.floatsOrder = order
end

-- Push functions

function data_buffer:put_byte(byte)
	if byte < 0 or byte > 255 then
		error("invalid byte")
	end

	if self.useBytearray then self.bytes:insert(self.pos, byte)
	else table.insert(self.bytes, self.pos, byte) end

	self.pos = self.pos + 1
end

function data_buffer:put_bit_buffer(buf)
	self:put_bytes(buf:get_bytes())
end

function data_buffer:put_bytes(bytes)
    if type(self.bytes) == 'table' then
        for i = 1, #bytes do
            self:put_byte(bytes[i])
        end
    else
        self.bytes:insert(self.pos, bytes)
        self.pos = self.pos + #bytes
    end
end

function data_buffer:put_norm8(single)
	self:put_bytes({bit_converter.norm8_to_byte(single)})
end

function data_buffer:put_norm16(single)
	self:put_bytes(bit_converter.norm16_to_bytes(single, self.order))
end

function data_buffer:put_float32(single)
	self:put_bytes(bit_converter.float32_to_bytes(single, self.order))
end

function data_buffer:put_float64(float)
	self:put_bytes(bit_converter.float64_to_bytes(float, self.order))
end

function data_buffer:put_string(str)
	self:put_bytes(bit_converter.string_to_bytes(str))
end

function data_buffer:put_bool(bool)
	self:pack("?", bool)
end

function data_buffer:put_uint16(uint16)
	self:pack("H", uint16)
end

function data_buffer:put_uint24(uint24)
	self:put_bytes(bit_converter.uint24_to_bytes(uint24, self.order))
end

function data_buffer:put_uint32(uint32)
	self:pack("I", uint32)
end

function data_buffer:put_sint16(int16)
	self:pack("h", int16)
end

function data_buffer:put_sint32(int32)
	self:pack("i", int32)
end

function data_buffer:put_int64(int64)
	self:pack("l", int64)
end

function data_buffer:put_any(value)
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
				self:put_sint16(value)
			elseif value >= MIN_INT32 then
				self:put_byte(TYPES.int32)
				self:put_sint32(value)
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

-- Get functions

function data_buffer:get_any()
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
        return self:get_sint16()
    elseif type_byte == TYPES.int32 then
        return self:get_sint32()
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

function data_buffer:get_byte()
	if self.bytes[self.pos] == nil and self.co then
		coroutine.yield()
		return self:get_byte()
	end
	local byte = self.bytes[self.pos]
	self.pos = self.pos + 1
	return byte
end

function data_buffer:get_norm8()
	return bit_converter.byte_to_norm8(self:get_byte())
end

function data_buffer:get_norm16()
	return bit_converter.bytes_to_norm16(self:get_bytes(2), self.order)
end

function data_buffer:get_uint24()
	return bit_converter.bytes_to_uint24(self:get_bytes(3), self.order)
end


function data_buffer:get_float32()
	return bit_converter.bytes_to_float32(self:get_bytes(4), self.order)
end

function data_buffer:get_float64()
	return bit_converter.bytes_to_float64(self:get_bytes(8), self.order)
end

function data_buffer:get_string()
	local str = bit_converter.bytes_to_string(self.bytes, self.pos)
	self.pos = self.pos + #str + 1
	return str
end

function data_buffer:get_bool()
	return self:unpack("?")
end

function data_buffer:get_uint16()
	return self:unpack("H")
end

function data_buffer:get_uint32()
	return self:unpack("I")
end

function data_buffer:get_sint16()
	return self:unpack("h")
end

function data_buffer:get_sint32()
	return self:unpack("i")
end

function data_buffer:get_int64()
	return self:unpack("l")
end

function data_buffer:size()
	return #self.bytes
end

function data_buffer:get_bytes(n)
	if n == nil then
		return self.bytes
	else
		local bytes = { }

		for i = 1, n do
			bytes[i] = self:get_byte()
		end

		return bytes
	end
end

function data_buffer:set_position(pos)
	self.pos = pos
end

function data_buffer:move_position(step)
	self.pos = self.pos + step
end

function data_buffer:set_bytes(bytes)
	for i = 1, #bytes do
		local byte = bytes[i]
		if byte < 0 or byte > 255 then
			error("invalid byte")
		end
	end

	self.bytes = bytes
end

setmetatable(data_buffer, data_buffer)

return data_buffer
