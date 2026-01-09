local Pipeline = require "lib/public/async_pipeline"
local protocol = require "multiplayer/protocol-kernel/protocol"
local protect = require "lib/private/protect"
local matches = require "multiplayer/server/handlers/general_matches"
local ClientPipe = require "multiplayer/server/client_pipe"
local List = require "lib/public/common/list"
local interceptors = require "api/v2/interceptors"
local receiver = require "server:multiplayer/protocol-kernel/receiver"

local ServerPipe = Pipeline.new()

ServerPipe:add_middleware(function(client)
    local co = client.meta.recieve_co
    if not co then
        client.meta.buffer = receiver.create_buffer()
        co = coroutine.create(function()
            while true do
                local received_any = false
                local buffer = client.meta.buffer
                while true do
                    local success, packet = pcall(function()
                        return protocol.parse_packet("client", buffer)
                    end)

                    if success and packet then
                        List.pushright(client.received_packets, packet)
                        received_any = true
                    elseif not success then
                        client:kick()
                        logger.log("Error while parsing packet: " .. packet .. '\n' .. "Client disconnected", 'E')
                        break
                    else
                        break
                    end
                end
                if not received_any then
                    coroutine.yield()
                end
            end
        end)
        client.meta.recieve_co = co
    end

    receiver.recv(client.meta.buffer, client)

    coroutine.resume(co)

    return client
end)

ServerPipe:add_middleware(function(client)
    print("Принят клиент: " .. client.client_id)
    if List.is_empty(client.received_packets) then
        print("пакетов нет у клиента")
        return client
    end

    print("активность клиента: " ..  tostring(client.active))

    local packet = List.popleft(client.received_packets)

    print("пакет имеет тип: " .. tostring(packet.packet_type))

    local success, err = pcall(function()
        if client.active == false then
            local status = interceptors.receive.__process(packet, client)
            print("Обрабатываем пакет со статусом: " .. tostring(status))
            if status then matches.general_fsm:handle_event(client, packet) end
        elseif client.active == true then
            print("Обрабатываем пакет: " .. tostring(client.client_id))
            matches.client_online_handler:switch(packet.packet_type, packet, client)
        end
    end)

    print("некст стейт\n")

    if not success then
        client:kick()
        logger.log("Error while reading packet: " .. err .. '\n' .. "Client disconnected", 'E')
    end

    return client, not List.is_empty(client.received_packets)
end)

ServerPipe:add_middleware(function(client)
    events.emit("server:client_pipe_start", client)
    if client.active then
        ClientPipe:process(client)
    end

    while not List.is_empty(client.response_queue) do
        local packet = List.popleft(client.response_queue)
        local success, err = pcall(function()
            client.network.socket:send(packet)
        end)
        if not success then
            logger.log("Error when sending a packet: " .. err, 'E')
            break
        end
    end

    return client
end)

return protect.protect_return(ServerPipe)