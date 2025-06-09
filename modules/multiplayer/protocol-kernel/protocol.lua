
local bit_buffer = require "server:lib/public/bit_buffer"
local compiler = require "server:multiplayer/protocol-kernel/compiler"
local protocol = {}
protocol.data = json.parse(file.read("server:default_data/protocol/protocol.json"))

function protocol.create_databuffer(bytes)
    local buf = bit_buffer:new(bytes, protocol.data.order)

    function buf.ownDb:put_packet(packet)
        local type = packet[1]
        packet:remove(1)

        self:put_byte(type)
        if protocol["serverParsers"][type+1].len == -1 then
            self:put_uint16(#packet)
        end

        self:put_bytes(packet)
    end

    function buf.ownDb:get_packet()
        local length = self:get_uint16()
        local sliced = protocol.slice_table(self.bytes, self.pos, self.pos + length - 1)
        self:set_position(self.pos + length)

        return sliced, length
    end

    function buf.ownDb:set_be()
        self:set_order("BE")
    end

    function buf.ownDb:set_le()
        self:set_order("LE")
    end

    return buf
end

function protocol.build_packet(client_or_server, packet_type, ...)
    local buffer = protocol.create_databuffer()
    buffer:put_byte(packet_type - 1)

    local encoder = protocol[client_or_server .. "Parsers"][packet_type].encoder
    local state, res = pcall(encoder, buffer, ...)

    if not state then
        logger.log("Packet encoding crash, additional information in server.log", 'E')

        logger.log("Error: " .. res, 'E', true)

        logger.log("Traceback:", 'E', true)
        logger.log(debug.traceback(), 'E', true)

        logger.log("Packet:", 'E', true)
        logger.log(table.tostring({client_or_server, packet_type}), 'E', true)

        logger.log("Data:", 'E', true)
        logger.log(json.tostring(...), 'E', true)
        return {}
    end
    buffer:flush()
    return buffer.bytes
end

function protocol.parse_packet(client_or_server, data)
    local result = {}
    local buffer = protocol.create_databuffer() -- для удобства создадим буфер
    buffer:put_bytes(data) -- запихаем в буфер все байты полученного пакета
    buffer:reset() -- движок поставит позицию в конец буфера, возвращаем обратно в начало
    local packet_type = buffer:get_byte() + 1
    result.packet_type = packet_type
    --print(packet_type)
    local packet_parser_info = protocol[client_or_server .. "Parsers"][packet_type]
    local decoder = packet_parser_info.decoder
    local names = packet_parser_info.names

    local state, res = pcall(decoder, buffer)

    if not state then
        logger.log("Packet parsing crash, additional information in server.log", 'E')

        logger.log("Error: " .. res, 'E', true)

        logger.log("Traceback:", 'E', true)
        logger.log(debug.traceback(), 'E', true)

        logger.log("Packet:", 'E', true)
        logger.log(table.tostring({client_or_server, packet_type}), 'E', true)

        logger.log("Data:", 'E', true)
        logger.log(table.tostring(data), 'E', true)
        return {}
    end

    for indx, name in ipairs(names) do
        result[name] = res[indx]
    end

    return result
end

protocol.ClientMsg = {}
-- Перечисление сообщений сервера
protocol.ServerMsg = {}
-- Перечисление статусов
protocol.States = {}
-- Версия протокола
protocol.Version = protocol.data.version

--Парсеры
protocol.serverParsers = {

}
protocol.clientParsers = {

}

local function create_parser(client_or_server, index, name_and_type)
    local types = {}
    local names = {}

    for _, raw_type in ipairs(name_and_type) do
        local parts = string.explode(':', raw_type)

        local name = parts[1]
        local type = parts[2]

        table.insert(types, type)
        table.insert(names, name)
    end

    local encoder, len = compiler.compile_encoder(types)
    local decoder = compiler.load(compiler.compile_decoder(types))

    protocol[client_or_server .. "Parsers"][index] = {
        encoder = compiler.load(encoder),
        decoder = decoder,
        names = names,
        len = len
    }
end

-- Парсим из json типы пакетов сервера
for index, value in ipairs(protocol.data.server) do
    protocol.ServerMsg[index] = value[1]
    protocol.ServerMsg[value[1]] = index

    create_parser("server", index, table.sub(value, 2))
end
-- Парсим из json типы пакетов клиента
for index, value in ipairs(protocol.data.client) do
    protocol.ClientMsg[index] = value[1] -- Имя типа пакета по индексу
    protocol.ClientMsg[value[1]] = index -- Индекс по имени типа пакета

    create_parser("client", index, table.sub(value, 2))
end
-- Парсим из json статусы
for index, value in ipairs(protocol.data.states) do
    protocol.States[index] = value
    protocol.States[value] = index
end

return protocol