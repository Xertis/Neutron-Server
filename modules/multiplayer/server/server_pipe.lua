local Pipeline = require "lib/public/pipeline"
local protocol = require "lib/public/protocol"
local matcher = require "lib/public/common/matcher"
local protect = require "lib/private/protect"

local List = require "lib/public/common/list"

local ServerPipe = Pipeline.new()

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

-- Обрабатываем пакеты

ServerPipe:add_middleware(function(client)
    local client_match = matcher.new(
        function ()
            logger.log("The expected package has been received, sending the status...")
            local buffer = protocol.create_databuffer()
            local icon = nil

            if file.exists(USER_ICON_PATH) then
                icon = file.read_bytes(USER_ICON_PATH)
            else
                icon = file.read_bytes(DEFAULT_ICON_PATH)
            end

            local players = {}

            local STATUS = {
                CONFIG.server.name,
                icon,
                CONFIG.game.version,
                protocol.data.version,
                players,
                CONFIG.game.worlds[CONFIG.game.main_world].seed,
                CONFIG.server.max_players,
                #players
            }

            buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.StatusResponse, unpack(STATUS)))
            client.network:send(buffer.bytes)
            logger.log("Status has been sended")
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

return protect.protect_return(ServerPipe)
