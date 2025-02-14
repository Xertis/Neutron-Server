local Pipeline = require "lib/public/pipeline"
local protocol = require "lib/public/protocol"
local protect = require "lib/private/protect"
local matches = require "multiplayer/server/server_matches"

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

    matches.status_request:set_default_data(client)
    matches.logging:set_default_data(client)

    while not List.is_empty(client.received_packets) do
        local packet = List.popleft(client.received_packets)

        if client.active == false then
            matches.status_request:match(packet)
            matches.logging:match(packet)
        elseif client.active == true then
            matches.client_online_handler:switch(packet.packet_type, packet, client)
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
