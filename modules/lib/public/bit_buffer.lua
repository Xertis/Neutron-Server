local bit_converter = require "lib/public/common/bit_converter"
local data_buffer = require "lib/public/data_buffer"

local bit_buffer =
{
	__call =
	function(bit_buffer, ...)
		return bit_buffer:new(...)
	end
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
	        	elseif bit_buffer[key] ~= nil then
	        		return bit_buffer[key]
	        	else
	        		local func = buf.ownDb[key]

	        		if type(func) == 'function' then
						if key:find('put') then
							return function(buf, ...)
								buf.ownDb.pos = 1
								func(buf.ownDb, ...)
							end
						elseif key:find('get') then
							return function(buf, ...)
								buf.ownDb.pos = 1

								local result = { func(buf.ownDb, ...) }

								return unpack(result)
							end
						end
	        		end
	        	end
	        end
	    }
    )

    obj.pos = 1
    obj.current = 0
	obj.current_is_zero = true

	if type(bytes) ~= "cdata" then
    	obj.bytes = Bytearray()
		for _, byte in ipairs(bytes or {}) do
			obj.bytes:append(byte)
		end
	else
		obj.bytes = bytes
	end

    obj.ownDb = data_buffer(nil, order or bit_converter.default_order)

	obj.ownDb.put_byte = function(db, n) obj:put_uint(n, 8) end
	obj.ownDb.get_byte = function(db) return obj:get_uint(8) end

    return obj
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
	local bit = getExp(self.bytes[math.ceil(self.pos / 8)], (self.pos - 1) % 8) ~= 0

	self.pos = self.pos + 1

	return bit
end

function bit_buffer:put_uint(num, width)
	for i = 1, width do
		self:put_bit(getExp(num, i - 1) ~= 0)
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

function bit_buffer:move_position(step)
	self.pos = self.pos + step
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

function bit_buffer:put_buffer(buf)
	self:put_bytes(buf:get_bytes())
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

setmetatable(bit_buffer, bit_buffer)

return bit_buffer
