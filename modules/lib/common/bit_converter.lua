local module = {}

function swap_endian(bytes)
  local swapped = {}
  local len = #bytes

  for i = len, 1, -1 do
    table.insert(swapped, bytes[i])
  end

  return swapped
end


function module.string_to_bytes(str, order)
	local bytes = { }

	local len = string.len(str)

	local lenBytes = byteutil.tpack(order .. "H", len)

	for i = 1, #lenBytes do
		bytes[i] = lenBytes[i]
	end

	for i = 1, len do
		bytes[#bytes + 1] = string.byte(string.sub(str, i, i))
	end

	return bytes
end

function module.bytes_to_string(bytes, pos, order)
	local len = byteutil.unpack(order .. "H",{ bytes[pos], bytes[pos+1] })

	local str = ""
  print(len)
	for i = pos+2, len+pos+1 do
    print(string.char(bytes[i]))
		str = str..string.char(bytes[i])
	end

	return str
end

function module.float_to_bytes(val, opt, order)
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

    if order == '>' then
      return swap_endian(bytes)
    end

    return bytes
end

function module.bytes_to_float(bytes, opt, order)
    if order == '>' then
      bytes = swap_endian(bytes)
    end

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

return module