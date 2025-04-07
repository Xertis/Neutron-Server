local bit_buffer =
{
	__call =
	function(bit_buffer, ...)
		return bit_buffer:new(...)
	end
}

local putExp = bit.compile("a | b << c")
local getExp = bit.compile("a & 1 << b")

function bit_buffer:new(bytes)
    local obj = {
        pos = 1,
        current = 0,
        bytes = Bytearray(bytes or {})
    }

    self.__index = self
    setmetatable(obj, self)

    return obj
end

function bit_buffer:put_bit(bit)
	self.current = putExp(self.current, bit and 1 or 0, (self.pos - 1) % 8)

	if bitIndex == 7 then
		bytes:append(self.current)
		self.current = 0
	end

	self.pos = self.pos + 1
end

function bit_buffer:get_bit()
	local bit = getExp(self.bytes[math.floor(self.pos / 8)], (self.pos - 1) % 8) ~= 0

	self.pos = self.pos + 1

	return bit
end

function bit_buffer:put_uint(num, width)
	for i = 1, width do
		self:put_bit(getExp(num, i - 1) == 1)
	end
end

function bit_buffer:get_uint(width)
	local num = 0

	for i = 1, width do
		num = putExp(num, self:get_bit() and 1 or 0, i - 1)
	end

	return num
end

function bit_buffer:get_position()
	return self.pos
end

function bit_buffer:set_position(pos)
	self.pos = pos
end

function bit_buffer:size()
	return self.pos
end

function bit_buffer:put_bytes(bytes)
	for i = 1, #bytes do
		self:put_uint(bytes[i], 8)
	end
end

function bit_buffer:put_data_buffer(buf)
	self:put_bytes(buf:get_bytes())
end

function bit_buffer:get_bytes(count)
	if not count then
		return self.bytes
	else
		local bytes = Bytearray()

		for i = 1, count do
			bytes:append(self.bytes[i])
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

setmetatable(bit_buffer, bit_buffer)

return bit_buffer