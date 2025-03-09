local bit_converter = { }

-- Credits to Iryont <https://github.com/iryont/lua-struct>

local function reverse(tbl)
      for i=1, math.floor(#tbl / 2) do
        local tmp = tbl[i]
        tbl[i] = tbl[#tbl - i + 1]
        tbl[#tbl - i + 1] = tmp
      end
    return tbl
end

local orders = { "LE", "BE" }

local fromLEConvertors =
{
        LE = function(bytes) return bytes end,
        BE = function(bytes) return reverse(bytes) end
}

local toLEConvertors =
{
        LE = function(bytes) return bytes end,
        BE = function(bytes) return reverse(bytes) end
}

bit_converter.default_order = "BE"

local function fromLE(bytes, orderTo)
    if orderTo then
        bit_converter.validate_order(orderTo)
        return fromLEConvertors[orderTo](bytes)
    else return bytes end
end

local function toLE(bytes, orderFrom)
    if orderFrom then
        bit_converter.validate_order(orderFrom)
        return toLEConvertors[orderFrom](bytes)
    else return bytes end
end

function bit_converter.validate_order(order)
    if not bit_converter.is_valid_order(order) then
         error("invalid order: "..order)
    end
end

local function floatOrDoubleToBytes(val, opt)
    local sign = 0

    if val < 0 then
      sign = 1
      val = -val
    end

    local mantissa, exponent = math.frexp(val)
    if val == 0 then
      mantissa = 0
      exponent = 0
    else
      mantissa = (mantissa * 2 - 1) * math.ldexp(0.5, (opt == 'd') and 53 or 24)
      exponent = exponent + ((opt == 'd') and 1022 or 126)
    end

    local bytes = {}
    if opt == 'd' then
      val = mantissa
      for i = 1, 6 do
        bytes[#bytes + 1] = math.floor(val) % (2 ^ 8)
        val = math.floor(val / (2 ^ 8))
      end
    else
      bytes[#bytes + 1] = math.floor(mantissa) % (2 ^ 8)
      val = math.floor(mantissa / (2 ^ 8))
      bytes[#bytes + 1] = math.floor(val) % (2 ^ 8)
      val = math.floor(val / (2 ^ 8))
    end

    bytes[#bytes + 1] = math.floor(exponent * ((opt == 'd') and 16 or 128) + val) % (2 ^ 8)
    val = math.floor((exponent * ((opt == 'd') and 16 or 128) + val) / (2 ^ 8))
    bytes[#bytes + 1] = math.floor(sign * 128 + val) % (2 ^ 8)
    val = math.floor((sign * 128 + val) / (2 ^ 8))

    return bytes
end

local function bytesToFloatOrDouble(bytes, opt)
    local n = (opt == 'd') and 8 or 4

    local sign = 1
    local mantissa = bytes[n - 1] % ((opt == 'd') and 16 or 128)
    for i = n - 2, 1, -1 do
      mantissa = mantissa * (2 ^ 8) + bytes[i]
    end

    if bytes[n] > 127 then
      sign = -1
    end

    local exponent = (bytes[n] % 128) * ((opt == 'd') and 16 or 2) + math.floor(bytes[n - 1] / ((opt == 'd') and 16 or 128))
    if exponent == 0 then
      return 0.0
    else
      mantissa = (math.ldexp(mantissa, (opt == 'd') and -52 or -23) + 1) * sign
      return math.ldexp(mantissa, exponent - ((opt == 'd') and 1023 or 127))
    end
end

function bit_converter.is_valid_order(order) return table.has(orders, order) end

function bit_converter.float32_to_bytes(float, order)
    return fromLE(floatOrDoubleToBytes(float, 'f'), order)
end

function bit_converter.float64_to_bytes(float, order)
    return fromLE(floatOrDoubleToBytes(float, 'd'), order)
end

function bit_converter.bytes_to_float32(bytes, order)
    return bytesToFloatOrDouble(toLE(bytes, order), 'f')
end

function bit_converter.bytes_to_float64(bytes, order)
    return bytesToFloatOrDouble(toLE(bytes, order), 'd')
end

function bit_converter.bytes_to_string(bytes)
  local len = byteutil.unpack("<H", {bytes[1], bytes[2]})

	local str = ""

	for i = 1, len do
		str = str..string.char(bytes[i + 2])
	end

	return str
end

function bit_converter.string_to_bytes(str)
	local bytes = { }

	local len = string.len(str)

	local lenBytes = byteutil.tpack("<H", len)

	for i = 1, #lenBytes do
		bytes[i] = lenBytes[i]
	end

	for i = 1, len do
		bytes[#bytes + 1] = string.byte(string.sub(str, i, i))
	end

	return bytes
end

function bit_converter.bool_to_byte(bool)
	return bool and 1 or 0
end

return bit_converter
