local bincode = require "lib/public/common/bincode"

local protocol = {}
local data_buffer = require "lib/public/data_buffer"
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
local data_decode = function (data_type, buffer) end
local data_encode = function (data_type, buffer) end


-- Функции для кодирования и декодирования разных типов значений
local DATA_ENCODE = {
    ["boolean"] = function(buffer, value)
        buffer:put_bool(value)
    end,
    ["byte"] = function(buffer, value)
        buffer:put_bytes(bincode.encode_varint(value))
    end,
    ["int8"] = function(buffer, value)
        buffer:put_byte(value < 0 and value + 256 or value)
    end,
    ["uint8"] = function(buffer, value)
        buffer:put_bytes(bincode.encode_varint(value))
    end,
    ["int16"] = function(buffer, value)
        buffer:put_sint16(value)
    end,
    ["uint16"] = function(buffer, value)
        buffer:put_bytes(bincode.encode_varint(value))
    end,
    ["int32"] = function(buffer, value)
        local result = bincode.zigzag_encode(value)
        buffer:put_bytes(bincode.encode_varint(result))
    end,
    ["uint32"] = function(buffer, value)
        buffer:put_bytes(bincode.encode_varint(value))
    end,
    ["int64"] = function(buffer, value)
        local result = bincode.zigzag_encode(value)
        buffer:put_bytes(bincode.encode_varint(result))
    end, -- TODO: сделать как на строке ниже
    ["uint64"] = function(buffer, value)
        buffer:put_bytes(bincode.encode_varint(value))
    end, -- TODO: зависимость от текущего порядка байтов в буфере
    ["float"] = function(buffer, value)
        buffer:put_float32(value)
    end,
    ["f32"] = function(buffer, value)
        buffer:put_float32(value)
    end, -- алиас для float
    ["double"] = function(buffer, value)
        buffer:put_float64(value)
    end,
    ["f64"] = function(buffer, value)
        buffer:put_float64(value)
    end, -- алиас для double
    ["string"] = function(buffer, value)
        buffer:put_bytes(pack_string(value))
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
}

local DATA_DECODE = {
    ["boolean"] = function(buffer)
        return buffer:get_bool()
    end,
    ["byte"] = function (buffer)
        return buffer:get_byte()
    end,
    ["int8"] = function(buffer)
        return buffer:get_byte()
    end,
    ["uint8"] = function(buffer)
        return bincode.decode_varint(buffer)
    end,
    ["int16"] = function(buffer)
        return buffer:get_sint16()
    end,
    ["uint16"] = function(buffer)
        return bincode.decode_varint(buffer)
    end,
    ["int32"] = function(buffer)
        local result = bincode.decode_varint(buffer)
        return bincode.zigzag_decode(result)
    end,
    ["uint32"] = function(buffer)
        return bincode.decode_varint(buffer)
    end,
    ["int64"] = function(buffer)
        local result = bincode.decode_varint(buffer)
        return bincode.zigzag_decode(result)
    end,
    ["uint64"] = function(buffer)
        return bincode.decode_varint(buffer)
    end,
    ["float"] = function(buffer)
        return buffer:get_float32()
    end,
    ["f32"] = function(buffer)
        return buffer:get_float32()
    end, -- алиас для float
    ["double"] = function(buffer)
        return buffer:get_float64()
    end,
    ["f64"] = function(buffer)
        return buffer:get_float64()
    end, -- алиас для double
    ["string"] = function(buffer)
        local string = unpack_string(buffer)
        return string
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

---Помощник для DATA_DECODE[array].
---Создан для доступа к своим же элементам. Объявлен выше ↑
---@param data_type string Строка, в которой закодирован тип данных
---@param buffer table Буфер
---@return string|number|table|unknown
data_decode = function (data_type, buffer)
    return DATA_DECODE[data_type](buffer)
end

data_encode = function (data_type, buffer)
    DATA_ENCODE[data_type](buffer)
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
            result[string.explode(":", type_descr)[1]] = DATA_DECODE[string.explode(":", type_descr)[2]](buffer, struct_descr)
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
    function buf:put_leb128(number)
        local bytes = protocol.leb128_encode(number)
        self:put_bytes(bytes)
    end
    ---Прочитать LEB128
    ---@return number
    function buf:get_leb128()
        local n, bytesRead = protocol.leb128_decode(self.bytes, self.pos)
        self.pos = self.pos + bytesRead
        return n
    end
    ---Записать пакет
    ---@param packet table Таблица байт
    function buf:put_packet(packet)
        -- local packet = protocol.build_packet(client_or_server, packet_type, ...)
        self:put_uint16(#packet) -- длина пакета, фиксировано 2 байта
        self:put_bytes(packet)
    end
    ---Прочитать пакет
    ---@return table table Таблица байт (пакет)
    ---@return number length Длина пакета
    function buf:get_packet()
        local length = self:get_uint16()
        local sliced = protocol.slice_table(self.bytes, self.pos, self.pos + length - 1)
        self:set_position(self.pos + length)
        -- local parsed = protocol.parse_packet(client_or_server, sliced)
        return sliced, length
    end

    ---Записать строку
    ---@param str string строка
    function buf:pack_string(str)
        DATA_ENCODE.string(self, str)
    end
    ---Прочитать строку
    ---@return string string строка
    function buf:unpack_string()
        return DATA_DECODE.string(self)
    end

    ---Установить порядок байт на Big-Endian (применяется только для последующих операций)
    function buf:set_be()
        self:set_order("BE")
    end
    ---Установить порядок байт на Little-Endian (применяется только для последующих операций)
    function buf:set_le()
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
    local args = {...}
    local buffer = protocol.create_databuffer()
    buffer:put_byte(packet_type - 1)
    -- TODO: поддержка structure и array
    for key, value in pairs(protocol.data[client_or_server][packet_type]) do
        if key > 1 then
            DATA_ENCODE[string.explode(":", value)[2]](buffer, args[key - 1])
        end
    end
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
    recursive_parse(data_struct, buffer, result)

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
