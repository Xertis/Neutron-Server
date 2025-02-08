local bc = require "lib/common/bit_converter"

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
    b = 1,
    B = 1,
    h = 2,
    H = 2,
    i = 4,
    I = 4,
    l = 8,
    L = 8,
    ['?'] = 1,

    F = {
        4,
        function (b, fchar) return bc.float_to_bytest(b[1], 'f', fchar) end,
        function (b, fchar, i)
            return i+4, bc.bytes_to_float(b, 'f', fchar)
        end
    },
    D = {
        8,
        function (b, fchar) return bc.float_to_bytest(b[1], 'd', fchar) end,
        function (b, fchar, i)
            return i+8, bc.bytes_to_float(b, 'd', fchar)
        end
    },
    S = {
        2,
        function (b, fchar) return bc.string_to_bytes(b[1], fchar) end,
        function (b, fchar, i, all_bytes)
            local len = byteutil.unpack(fchar .. 'H', {b[1], b[2]})
            return i+len+2, bc.bytes_to_string(all_bytes, i-1, fchar)
        end
    }
}

local module =
{
	__call =
	function(module, ...)
		return module:new(...)
	end
}

function table.slice(arr, start, stop)
    local sliced = {}
    start = start or 1
    stop = stop or #arr

    for i = start, stop do
        table.insert(sliced, arr[i])
    end

    return sliced
end

local function __get_size__(pattern, types)
    local size = 0
    for i=2, #pattern do
        local vsize = types[pattern[i]]
        if type(vsize)[1] == 't' then
            vsize = types[pattern[i]][1]
        end

        size = size + vsize
    end

    return size
end

local function __slice__(pattern)
    local first_char = pattern:sub(1, 1)

    local parts = {}
    local temp = ""
    for i = 1, #pattern do
        local char = pattern:sub(i, i)
        if STANDART_TYPES[char] == nil then
            if temp ~= "" then
                table.insert(parts, temp)
                temp = ""
            end
            table.insert(parts, char)
        else
            temp = temp .. char
        end
    end
    if temp ~= "" then
        table.insert(parts, temp)
    end

    return first_char, parts
end

function module:new(bytes)
	bytes = bytes or { }


    local obj = {
        pos = 1,
        bytes = bytes,
        types = TYPES
    }

    self.__index = self
    setmetatable(obj, self)

    return obj
end

function module:create_type(type, min_size, pack, unpack)
    self.types[type] = {min_size, pack, unpack}
end

function module:add(bytes)
	for i = 1, #bytes do
		self:put_byte(bytes[i])
	end
end

function module:pack(format, values)
    local fchar, formats = __slice__(format)
    local res = {}

    if formats[1] == '>' or formats[1] == '<' then
        table.remove(formats, 1)
    else
        formats[1] = formats[1]:sub(2)
    end

    local i = 1

    for _=1, #formats do
        local pattern = formats[_]
        local b = table.slice(values, i)

        if STANDART_TYPES[pattern] == nil then
            local bval = self.types[pattern][2](b, fchar)
            self:add(bval)
        else
            pattern = fchar .. pattern
            local x = byteutil.tpack(pattern, unpack(b))
            i = i + #pattern - 2
            self:add(x)
        end

        i = i + 1
	end

    return res
end

function module:unpack(format)
    local fchar, formats = __slice__(format)
    local res = {}

    if formats[1] == '>' or formats[1] == '<' then
        table.remove(formats, 1)
    else
        formats[1] = formats[1]:sub(2)
    end

    local i = self.pos

    for _=1, #formats do
        local pattern = formats[_]
        local b = table.slice(self.bytes, i, i+__get_size__(' ' .. pattern, self.types))

        if STANDART_TYPES[pattern] == nil then
            local val = nil
            i, val = self.types[pattern][3](b, fchar, i, self.bytes)
            table.insert(res, val)
        else
            pattern = fchar .. pattern
            local x = {byteutil.unpack(pattern, b)}
            for _, val in ipairs(x) do
                table.insert(res, val)
            end

            i = i + __get_size__(pattern, self.types)
        end
	end

    self.pos = i

    return res
end

function module:put_byte(byte)
	if byte < 0 or byte > 255 then
		error("invalid byte")
	end

	table.insert(self.bytes, byte)
end

function module:get_byte()
	local byte = self.bytes[self.pos]
	self.pos = self.pos + 1
	return byte
end

function module:get_bytes(n)
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

function module:set_position(pos)
	self.pos = pos
end

function module:set_bytes(bytes)
	for i = 1, #bytes do
		local byte = bytes[i]
		if byte < 0 or byte > 255 then
			error("invalid byte")
		end
	end

	self.bytes = bytes
end

function module:put_bytes(bytes)
    if type(self.bytes) == 'table' then
        for i = 1, #bytes do
            self:put_byte(bytes[i])
        end
    else
        self.bytes:insert(self.pos, bytes)
        self.pos = self.pos + #bytes
    end
end

function module:size()
    return #self.bytes
end

return module