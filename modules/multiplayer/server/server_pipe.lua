local Pipeline = require "lib/public/pipeline"
local protocol = require "lib/public/protocol"
local ssm = require "lib/public/common/ssm"
local matcher = require "lib/public/common/matcher"

local List = require "lib/public/common/list"

local ServerPipe = Pipeline.new()

local function push_packet(list, packet)
    local buffer = protocol.create_databuffer()
    buffer:put_packet(packet)
    List.pushright(list, buffer.bytes)
end

local function global_chat(msg)
    console.log("| " .. msg)
    for _, client in ipairs(Session.server.clients) do
        if client.active then
            push_packet(client.response_queue, protocol.build_packet("server", protocol.ServerMsg.ChatMessage, 0, msg, 0))
        end
    end
end

-- Принимаем все пакеты
ServerPipe:add_middleware(function(client)
    local packet_count = 0
    local max_packet_count = 10
    while packet_count < max_packet_count do
        local length_bytes = client.network:recieve_bytes(2)
        if length_bytes then
            local length_buffer = protocol.create_databuffer(length_bytes)
            local length = length_buffer:get_uint16()
            if length then
                local data_bytes = client.network:recieve_bytes(length)
                if data_bytes then
                    local packet = protocol.parse_packet("client", data_bytes)
                    List.pushright(client.received_packets, packet)
                    packet_count = packet_count + 1
                else break end
            else break end
        else break end
    end
    return client
end)

-- TODO: перевести на новый протокол
-- Обрабатываем пакеты

ServerPipe:add_middleware(function(client)
    local client_match = matcher.new(
        function ()
            logger.log("The expected package has been received, sending the status...")
            local buffer = protocol.create_databuffer()

            local STATUS = { -- В СКОРОМ БУДУЩЕМ ЗАМЕНИТЬ, НУЖНО ТОЛЬКО ДЛЯ ТЕСТА
                CONFIG.server.name,
                file.read_bytes("user:icon.png"),
                "0.26.0",
                1,
                {},
                CONFIG.game.worlds[CONFIG.game.main_world].seed,
                CONFIG.server.max_players,
                0
            }

            buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.StatusResponse, unpack(STATUS)))
            client.network:send(buffer.bytes)
            logger.log("Sended")
        end
    )

    client_match:add_match(
        function (val)
            if val.packet_type == protocol.ClientMsg.HandShake then
                return true
            end
        end
    )
    client_match:add_match(
        function (val)
            if val.packet_type == protocol.ClientMsg.StatusRequest then
                return true
            end
        end
    )


    while not List.is_empty(client.received_packets) do
        local packet = List.popleft(client.received_packets)
        if client.active == false then
            client_match:match(packet)
        end
    end
    return client
end)

-- TODO: Проверим, не отключился ли вдруг клиент
-- оказалось, такая проверка уже есть при старте процессинга трубы.

-- TODO: Отправляем на очередь всё, что хотим отправить клиенту

-- Отправляем всё, что не отправили
ServerPipe:add_middleware(function(client)
    while not List.is_empty(client.response_queue) do
        local packet = List.popleft(client.response_queue)
        client.network:send(packet)
    end
    return client
end)

return ServerPipe
