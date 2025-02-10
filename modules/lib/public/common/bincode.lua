local data_buffer = require "lib/public/data_buffer"
local bincode = {}

-- нейронка вампала много помогла с кодированием в leb128

--- Кодирование числа в формат Bincode Varint
--- @param n number Число для кодирования
--- @return string encoded Закодированное число в строке
function bincode.bincode_varint_encode(n)
    local bytes = {}
    if n < 251 then
        table.insert(bytes, string.char(n))
    elseif n >= 251 and n < 2 ^ 16 then
        table.insert(bytes, string.char(251))
        table.insert(bytes, string.char(n % 256))
        table.insert(bytes, string.char(math.floor(n / 256)))
    elseif n >= 2 ^ 16 and n < 2 ^ 32 then
        table.insert(bytes, string.char(252))
        table.insert(bytes, string.char(n % 256))
        n = math.floor(n / 256)
        table.insert(bytes, string.char(n % 256))
        n = math.floor(n / 256)
        table.insert(bytes, string.char(n % 256))
        n = math.floor(n / 256)
        table.insert(bytes, string.char(n))
    elseif n >= 2 ^ 32 and n < 2 ^ 64 then
        table.insert(bytes, string.char(253))
        for i = 0, 7 do
            table.insert(bytes, string.char(n % 256))
            n = math.floor(n / 256)
        end
        -- Если добавить поддержку чисел больше 2^64, то придется либо использовать
        -- что-то кроме string.char (например, string.pack), либо работать с числами
        -- по частям, так как Lua 5.1 не поддерживает нативно целые числа больше 2^53.
        -- elseif n >= 2^64 and n < 2^128 then
        --     table.insert(bytes, string.char(254))
        --     -- ...
    else
        error("Bincode Varint encoding: Number too large for Lua 5.1")
    end
    return table.concat(bytes)
end

--- Декодирование числа из формата Bincode Varint
--- @param data string Строка для декодирования
--- @param pos integer Позиция начала закодированной длины в данной таблице
--- @return number result Декодированное число
--- @return number nextPos Позиция после декодированного числа
function bincode.bincode_varint_decode(data, pos)
    if not pos then
        pos = 1
    end
    local firstByte = string.byte(data, pos)
    if firstByte < 251 then
        return firstByte, pos + 1
    elseif firstByte == 251 then
        local result = string.byte(data, pos + 1) + string.byte(data, pos + 2) * 256
        return result, pos + 3
    elseif firstByte == 252 then
        local result = string.byte(data, pos + 1) + string.byte(data, pos + 2) * 256 + string.byte(data, pos + 3) *
                           65536 + string.byte(data, pos + 4) * 16777216
        return result, pos + 5
    elseif firstByte == 253 then
        local result = 0
        for i = 1, 8 do
            result = result + string.byte(data, pos + i) * (256 ^ (i - 1))
        end
        return result, pos + 9
        -- elseif firstByte == 254 then
        --     -- ...
    else
        error("Bincode Varint decoding: Invalid marker byte")
    end
end

local function to_uint32(value)
    return value < 0 and value + 2 ^ 32 or value
end

--- Декодирование числа из формата Bincode Varint
--- @param buffer data буффер для декодирования
--- @return number result Декодированное число
function bincode.decode_varint(buffer)
    local first_byte = buffer:get_byte()
    -- If the first byte is less than 251, it's a single byte encoding
    if first_byte < 251 then
        return first_byte
        -- If the first byte is 251, we expect a 16-bit value
    elseif first_byte == 251 then
        return buffer:get_uint16()
        -- If the first byte is 252, we expect a 32-bit value
    elseif first_byte == 252 then
        return byteutil.unpack(">I", buffer:get_bytes(4))
        -- If the first byte is 253, we expect a 64-bit value
    elseif first_byte == 253 then
        return byteutil.unpack(">L", buffer:get_bytes(8))
        -- If the first byte is 254, we expect a 128-bit value
    elseif first_byte == 254 then
        -- Since Lua doesn't have built-in support for 128-bit integers,
        -- you might need to handle this case differently (perhaps with a string representation).
        -- This is a placeholder for future implementation if needed.
        error("128-bit integers not supported in this Lua environment.")
    else
        error("Invalid varint encoding.")
    end
end

--- Декодирование числа из формата Bincode Varint
--- @param value number буффер для декодирования
--- @return byteArray result Декодированное число
function bincode.encode_varint(value)
    local buffer = data_buffer:new()
    -- If the first byte is less than 251, it's a single byte encoding
    if value < 251 then
        buffer:put_byte(value)
        -- If the first byte is 251, we expect a 16-bit value
    elseif value <= 65535 then
        buffer:put_byte(251)
        buffer:put_uint16(value)
        -- If the first byte is 252, we expect a 32-bit value
    elseif value <= 4294967295 then
        buffer:put_byte(252)
        buffer:put_bytes(byteutil.tpack(">I", value))
        -- If the first byte is 253, we expect a 64-bit value
    elseif value > 4294967295 then
        buffer:put_byte(253)
        buffer:put_bytes(byteutil.tpack(">L", value))
    end

    return buffer:get_bytes()
end

---Кодирование числа в формат LEB128
---@param n number Число для кодирования
---@return string encoded Закодированное число в строке
function bincode.leb128_encode(n)
    local bytes = {}
    repeat
        local byte = n % 128
        n = math.floor(n / 128)
        if n ~= 0 then
            byte = byte + 128 -- Устанавливаем бит продолжения
        end
        table.insert(bytes, string.char(byte))
    until n == 0
    return table.concat(bytes)
end

---Декодирование числа из формата LEB128
---@param data string Строка для декодирования
---@param pos integer Позиция начала закодированной длины в данной таблице
---@return number result Декодированное число
---@return number bytesRead Количество прочитанных байт
function bincode.leb128_decode(data, pos)
    if not pos then
        pos = 1
    end
    local result = 0
    local shift = 0
    local bytesRead = 0
    for i = pos, #data do
        local byte = string.byte(data, i)
        local value = byte % 128
        result = result + value * (128 ^ shift)
        bytesRead = bytesRead + 1
        if byte < 128 then
            break
        end
        shift = shift + 1
    end
    return result, bytesRead + pos
end

function bincode.zigzag_encode(v)
    if v == 0 then
        return 0
    elseif v < 0 then
        return -v * 2 - 1
    elseif v > 0 then
        return v * 2
    end
end

function bincode.zigzag_decode(encoded)
    if encoded == 0 then
        return 0
    elseif encoded % 2 == 1 then
        return -math.floor((encoded + 1) / 2)
    else
        return math.floor(encoded / 2)
    end
end


return bincode
