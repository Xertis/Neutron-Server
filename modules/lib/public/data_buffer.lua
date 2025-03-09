local bit_converter = require "lib/public/common/bit_converter"

-- Data buffer

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

local data_buffer =
{
	__call =
	function(data_buffer, ...)
		return data_buffer:new(...)
	end
}

function data_buffer:new(bytes, order, useBytearray)
	bytes = bytes or { }

	if order then bit_converter.validate_order(order)
	else order = bit_converter.default_order end

    local obj = {
        pos = 1,
        order = order,
        useBytearray = useBytearray or false,
        bytes = useBytearray and Bytearray(bytes) or bytes
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

-- Get functions

function data_buffer:get_byte()
	local byte = self.bytes[self.pos]
	self.pos = self.pos + 1
	return byte
end

function data_buffer:get_float32()
	return bit_converter.bytes_to_float32(self:get_bytes(4), self.order)
end

function data_buffer:get_float64()
	return bit_converter.bytes_to_float64(self:get_bytes(8), self.order)
end

function data_buffer:get_string()
	local len = self:get_bytes(2)
	local str = self:get_bytes(byteutil.unpack("<H", {len[1], len[2]}))
	local bytes = { }

	for i = 1, #len do
		bytes[i] = len[i]
	end

	for i = 1, #str do
		bytes[#bytes + 1] = str[i]
	end

	return bit_converter.bytes_to_string(bytes)
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
