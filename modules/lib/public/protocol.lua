local bincode = require "lib/public/common/bincode"
local bson = require "lib/private/files/bson"

local MAX_UINT16 = 65535
local MIN_UINT16 = 0
local MAX_UINT32 = 4294967295
local MIN_UINT32 = 0
local MAX_UINT64 = 18446744073709551615
local MIN_UINT64 = 0

local MAX_BYTE = 255
local MIN_BYTE = 0

local MAX_INT8 = 127
local MAX_INT16 = 32767
local MAX_INT32 = 2147483647
local MAX_INT64 = 9223372036854775807

local MIN_INT8 = -127
local MIN_INT16 = -32768
local MIN_INT32 = -2147483648
local MIN_INT64 = -9223372036854775808

local protocol = {}
local data_buffer = require "lib/public/bit_buffer"
protocol.data = json.parse(file.read("server:default_data/protocol.json"))

---Кодирование строки
---@param str string Строка, которая будет закодирована
---@return table bytes Таблица с закодированной длиной строки
local function pack_string(str)
    local len = #str
    return utf8.tobytes(bincode.bincode_varint_encode(len) .. str, true)
end

---Декодирование строки
---@param data table Таблица с закодированной длиной строки
---@return string string Декодированная строка
local function unpack_string(data)
    local len = bincode.decode_varint(data)
    local str = utf8.tostring(data:get_bytes(len))
    return str
end

protocol.slice_table = function(tbl, first, last, step)
    local sliced = {}

    for i = first or 1, last or #tbl, step or 1 do
        sliced[#sliced + 1] = tbl[i]
    end

    return sliced
end

-- чтобы функции были доступны из DATA_DECODE
local recursive_parse = function (data_struct, buffer, result) end
local recursive_encode = function (data_struct, buffer, result) end
local data_decode = function (data_type, buffer) end
local data_encode = function (data_type, buffer, value) end

-- Функции для кодирования и декодирования разных типов значений
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
    end,
    ["byteArray"] = function(buffer, value)
        buffer:put_bytes(bincode.encode_varint(#value))
        buffer:put_bytes(value)
    end,
    ["stringArray"] = function(buffer, value)
        buffer:put_bytes(bincode.encode_varint(#value))
        for i = 1, #value, 1 do
            buffer:pack_string(value[i])
        end
    end,
    ["array"] = function (buffer, value, data_type)
        buffer:put_bytes(bincode.encode_varint(#value))
        for i = 1, #value, 1 do
            data_encode(data_type, buffer, value[i])
        end
    end,
    ["structure"] = function (buffer, value, struct_name)
        local struct_index = 0

        for index, structure in ipairs(protocol.Structures) do
            if structure[1] == struct_name then struct_index = index break end end

        buffer:put_bytes(bincode.encode_varint(#value))
        for i = 1, #value, 1 do
            recursive_encode(protocol.Structures[struct_index], value[i], buffer)
        end
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
    end,
    ["structure"] = function (buffer, struct_name)
        local result = {}
        local struct_index = 0
        -- узнаём индекс нужной структуры
        for index, structure in ipairs(protocol.Structures) do
            if structure[1] == struct_name then struct_index = index break end end

        local vec_length = bincode.decode_varint(buffer)
        -- TODO: уточнить у вампала, кодируется ли количество элементов Vec<T> в varint или leb128
        -- но пока не ёбнет пусть будет varint
        for i = 1, vec_length, 1 do
            result[i] = {}
            recursive_parse(protocol.Structures[struct_index], buffer, result[i])
        end

        return result
    end,
    ["array"] = function (buffer, data_type)
        local result = {}
        local array_length = bincode.decode_varint(buffer)

        for i = 1, array_length, 1 do
            result[#result+1] = data_decode(data_type, buffer)
        end
        return result
    end
}

STATIC_ENCODE = {
    ["$particle"] = function(buffer, value)
        local config = (type(value.origin) == "number" and 1 or 0) + (value.extension and 2 or 0)

        -- 0: origin - позиция, ext нету
        -- 1: origin - uid, ext нету
        -- 2: origin - позиция, ext есть
        -- 3: origin - uid, ext есть

        buffer:put_uint32(value.pid)
        buffer:put_byte(config)

        --ORIGIN
        if config == 0 or config == 3 then
            buffer:put_float32(value.origin[1])
            buffer:put_float32(value.origin[2])
            buffer:put_float32(value.origin[3])
        else
            buffer:put_uint32(value.origin)
        end

        --COUNT
        buffer:put_uint16(math.clamp(value.count + 1, 0, MAX_UINT16))

        --PRESET
        bson.encode(buffer, value.preset)

        if config == 2 or config == 3 then
            bson.encode(buffer, value.extension)
        end
    end,
    ["$particle_origin"] = function (buffer, value)
        buffer:put_uint32(value.pid)
        if type(value.origin) == "number" then
            buffer:put_bool(false)
            buffer:put_uint32(value.origin)
        else
            local x, y, z = unpack(value.origin)
            buffer:put_bool(true)
            buffer:put_float32(x)
            buffer:put_float32(y)
            buffer:put_float32(z)
        end
    end
}

STATIC_DECODE = {
    ["$particle"] = function (buffer)
        local value = {}

        value.pid = buffer:get_uint32()
        local config = buffer:get_byte()

        if config == 0 or config == 3 then
            value.origin = {}
            value.origin[1] = buffer:get_float32()
            value.origin[2] = buffer:get_float32()
            value.origin[3] = buffer:get_float32()
        else
            value.origin = buffer:get_uint32()
        end

        value.count = buffer:get_uint16() - 1
        value.preset = bson.decode(buffer)
        if config == 2 or config == 3 then
            value.extension = bson.decode(buffer)
        end

        return value
    end,
    ["$particle_origin"] = function (buffer)
        local value = {}

        value.pid = buffer:get_uint32()
        if not buffer:get_bool() then
            value.origin = buffer:get_uint32()
        else
            value.origin = {buffer:get_float32(), buffer:get_float32(), buffer:get_float32()}
        end

        return value
    end
}

table.merge(DATA_ENCODE, STATIC_ENCODE)
table.merge(DATA_DECODE, STATIC_DECODE)

---Помощник для DATA_DECODE[array].
---Создан для доступа к своим же элементам. Объявлен выше ↑
---@param data_type string Строка, в которой закодирован тип данных
---@param buffer table Буфер
---@return string|number|table|unknown
data_decode = function (data_type, buffer)
    return DATA_DECODE[data_type](buffer)
end

data_encode = function (data_type, buffer, value)
    DATA_ENCODE[data_type](buffer, value)
end

---Помощник парсера пакетов. Используется в DATA_ENCODE
---и protocol.parse_packet. Позволяет парсить структуры. Объявлен выше ↑
---@param data_struct table Структура данных (может содержать другие структуры)
---@param buffer table Буфер
---@param result table Таблица, в которой будут записаны данные
recursive_parse = function(data_struct, buffer, result)
    for key, value in pairs(data_struct) do
        if key ~= 1 then
            local type_descr = string.explode("|", value)[1]
            local struct_descr = string.explode("|", value)[2]
            local func = DATA_DECODE[string.explode(":", type_descr)[2]]
            local res = func(buffer, struct_descr)
            result[string.explode(":", type_descr)[1]] = res
        end
    end
end

recursive_encode = function(data_struct, data, buffer)
    for key, value in pairs(data_struct) do
        if key ~= 1 then
            local type_descr = string.explode("|", value)[1]
            local struct_descr = string.explode("|", value)[2]

            local data_type = string.explode(":", type_descr)[2]
            local data_value = data[key-1]

            DATA_ENCODE[data_type](buffer, data_value, struct_descr)
        end
    end
end

---Создаёт датабуфер с порядком Big Endian
---@param bytes table|nil [Опционально] Таблица с байтами
---@return table data_buffer Датабуфер
function protocol.create_databuffer(bytes)
    local buf = data_buffer:new(bytes, protocol.data.order)
    ---Записать LEB128
    ---@param number number
    function buf.ownDb:put_leb128(number)
        local bytes = protocol.leb128_encode(number)
        self:put_bytes(bytes)
    end
    ---Прочитать LEB128
    ---@return number
    function buf.ownDb:get_leb128()
        local n, bytesRead = protocol.leb128_decode(self.bytes, self.pos)
        self.pos = self.pos + bytesRead
        return n
    end
    ---Записать пакет
    ---@param packet table Таблица байт
    function buf.ownDb:put_packet(packet)
        -- local packet = protocol.build_packet(client_or_server, packet_type, ...)
        self:put_uint16(#packet) -- длина пакета, фиксировано 2 байта
        self:put_bytes(packet)
    end
    ---Прочитать пакет
    ---@return table table Таблица байт (пакет)
    ---@return number length Длина пакета
    function buf.ownDb:get_packet()
        local length = self:get_uint16()
        local sliced = protocol.slice_table(self.bytes, self.pos, self.pos + length - 1)
        self:set_position(self.pos + length)
        -- local parsed = protocol.parse_packet(client_or_server, sliced)
        return sliced, length
    end

    ---Записать строку
    ---@param str string строка
    function buf.ownDb:pack_string(str)
        DATA_ENCODE.string(self, str)
    end
    ---Прочитать строку
    ---@return string string строка
    function buf.ownDb:unpack_string()
        return DATA_DECODE.string(self)
    end

    ---Установить порядок байт на Big-Endian (применяется только для последующих операций)
    function buf.ownDb:set_be()
        self:set_order("BE")
    end
    ---Установить порядок байт на Little-Endian (применяется только для последующих операций)
    function buf.ownDb:set_le()
        self:set_order("LE")
    end

    return buf
end

---Создатель пакетов
---@param client_or_server string "client" или "server" - сторона, на которой создаётся пакет
---@param packet_type integer Тип пакета
---@param ... any Дополнительные параметры пакета
---@return table bytes Пакет
function protocol.build_packet(client_or_server, packet_type, ...)
    local data = {...}
    local buffer = protocol.create_databuffer()
    buffer:put_byte(packet_type - 1)

    local data_struct = protocol.data[client_or_server][packet_type]
    local state, res = pcall(recursive_encode, data_struct, data, buffer)

    if not state then
        logger.log("Packet encoding crash, additional information in server.log", 'E')

        logger.log("Traceback:", 'E', true)
        logger.log(res, 'E', true)
        logger.log(debug.traceback(), 'E', true)

        logger.log("Packet:", 'E', true)
        logger.log(table.tostring({client_or_server, packet_type}), 'E', true)

        logger.log("Data:", 'E', true)
        logger.log(json.tostring(...), 'E', true)
    end
    buffer:flush()
    return buffer.bytes
end

---Парсер пакетов
---@param client_or_server string "client" или "server" - сторона, откуда пришёл пакет
---@param data table Таблица с байтами (пакет)
---@return table parameters Список извлечённых параметров
function protocol.parse_packet(client_or_server, data)
    local result = {} -- вернём удобный список полученных значений
    local buffer = protocol.create_databuffer() -- для удобства создадим буфер
    buffer:put_bytes(data) -- запихаем в буфер все байты полученного пакета
    buffer:set_position(1) -- движок поставит позицию в конец буфера, возвращаем обратно в начало
    local packet_type = buffer:get_byte() + 1
    result.packet_type = packet_type
    local data_struct = protocol.data[client_or_server][packet_type] or {}
    -- TODO: улучшить парсинг для возможности парсинга структур (сделано) и массивов (сделано)

    local state, res = pcall(recursive_parse, data_struct, buffer, result)

    if not state then
        logger.log("Packet parsing crash, additional information in server.log", 'E')

        logger.log("Traceback:", 'E', true)
        logger.log(debug.traceback(), 'E', true)

        logger.log("Packet:", 'E', true)
        logger.log(table.tostring({client_or_server, packet_type}), 'E', true)

        logger.log("Data:", 'E', true)
        logger.log(table.tostring(data), 'E', true)
    end

    return result
end

-- TODO: чекер Protocol Packet
---Средство проверки пакета
---@param client_or_server string "client" или "server" - сторона, откуда пришёл пакет
---@param packet table Таблица с байтами (пакет)
---@return boolean success Успешность проверки пакета
function protocol.check_packet(client_or_server, packet)
    -- вопрос: на что чекать пакет?
    -- 1. было бы классно проверять, не наебал ли нас клиент/сервер с длиной пакета
    -- 2. теперь можно спарсить весь пакет, и если вдруг пакета не хватило или осталось с избытком, считаем, что пакет повреждён
    -- 3. если при парсинге пакета вдруг резко оказалось что тип пакета неизвестен, выкидываем
    -- проверки по типу соответствии никнейма со стандартом, длины никнейма и так далее будут за пределами этой функции
    -- только после успешной проверки функция вернёт true, а если нет - false, тогда сервер может кикнуть за malformed packet

    -- пока что будем считать, что все пакеты ровненькие и красивенькие
    return true
end

-- закомментировал лишнее. если что-нибудь без этого ёбнет, раскомментировать.
-- function protocol.parse_array_of(structure, data)
--     local elements = {}
--     local buffer = data_buffer()

--     buffer:put_bytes(data)
--     buffer:set_position(1)

--     while buffer.pos < buffer:size() do
--         local element = {}

--         local __table = protocol.data.structures[structure] or {}
--         for key, value in pairs(__table) do
--             if key ~= 1 then
--                 element[string.explode(":", value)[1]] = DATA_DECODE[string.explode(":", value)[2]](buffer)
--             end
--         end
--     end

--     return elements
-- end

-- Перечисление сообщений клиента
protocol.ClientMsg = {}
-- Перечисление сообщений сервера
protocol.ServerMsg = {}
-- Перечисление статусов
protocol.States = {}
-- Перечисление Структур
protocol.Structures = {}

protocol.Version = protocol.data.version

-- Парсим из json типы пакетов клиента и сервера
for index, value in ipairs(protocol.data.client) do
    protocol.ClientMsg[index] = value[1] -- Имя типа пакета по индексу
    protocol.ClientMsg[value[1]] = index -- Индекс по имени типа пакета
end
for index, value in ipairs(protocol.data.server) do
    protocol.ServerMsg[index] = value[1]
    protocol.ServerMsg[value[1]] = index
end
-- Парсим из json статусы
for index, value in ipairs(protocol.data.states) do
    protocol.States[index] = value
    protocol.States[value] = index
end
-- Парсим из json Структуры
for index, value in ipairs(protocol.data.structures) do
    protocol.Structures[index] = value
    protocol.Structures[value] = index
end

-- выставляем в свет функцию leb128_чего-то-там, но теперь функция возвращает таблицу с байтами и принимает
-- тоже таблицу с байтами для удобства работы вне библиотеки

---Кодирование числа в формат LEB128
---@param n number Число для кодирования
---@return table encoded Закодированное число в таблице байтов
protocol.leb128_encode = function(n)
    return utf8.tobytes(bincode.leb128_encode(n), true)
end

---Декодирование числа из формата LEB128
---@param bytes table Таблица байт для декодирования
---@param pos integer Позиция начала закодированной длины в данной таблице
---@return number result Декодированное число
---@return number bytesRead Количество прочитанных байт
protocol.leb128_decode = function(bytes, pos)
    return bincode.leb128_decode(utf8.tostring(bytes), pos)
end

-- local bignum = 1234567890123
-- debug.print(bignum.."")
-- local buf = protocol.create_databuffer()
-- buf:put_bytes(byteutil.tpack('>l', bignum))
-- debug.print(buf)
-- buf.pos = 1
-- debug.print(byteutil.unpack('>l', buf.bytes).."")

return protocol