local Pipeline = require "lib/public/async_pipeline"
local protocol = require "multiplayer/protocol-kernel/protocol"
local protect = require "lib/private/protect"
local matches = require "multiplayer/server/server_matches"
local ClientPipe = require "multiplayer/server/client_pipe"
local List = require "lib/public/common/list"

local ServerPipe = Pipeline.new()

ServerPipe:add_middleware(function(client)
    local co = client.meta.recieve_co
    if not co then
        co = coroutine.create(function()
            while true do
                local received_any = false
                while true do
                    local length_bytes = client.network:recieve_bytes(2)
                    if not length_bytes then
                        break
                    end
                    local success, length = pcall(function()
                        local buffer = protocol.create_databuffer(length_bytes)
                        return buffer:get_uint16()
                    end)

                    if not success or not length then
                        break
                    end
                    local data_bytes = client.network:recieve_bytes(length)
                    if not data_bytes or #data_bytes < length then
                        break
                    end

                    local success, packet = pcall(function()
                        return protocol.parse_packet("client", data_bytes)
                    end)

                    if success and packet then
                        List.pushright(client.received_packets, packet)
                        received_any = true
                    end
                end
                if not received_any then
                    coroutine.yield()
                end
            end
        end)
        client.meta.recieve_co = co
    end
    coroutine.resume(co)
    return client
end)

ServerPipe:add_middleware(function(client)
    if List.is_empty(client.received_packets) then
        return client
    end

    local packet = List.popleft(client.received_packets)

    local success, err = pcall(function()
        if client.active == false then
            matches.fsm:handle_event(client, packet)
        elseif client.active == true then
            matches.client_online_handler:switch(packet.packet_type, packet, client)
        end
    end)

    if not success then
        logger.log("Error while reading packet: " .. err, 'E')
    end

    return client, not List.is_empty(client.received_packets)
end)

ServerPipe:add_middleware(function(client)
    if client.active then
        ClientPipe:process(client)
    end

    while not List.is_empty(client.response_queue) do
        local packet = List.popleft(client.response_queue)
        local success, err = pcall(function()
            client.network:send(packet)
        end)
        if not success then
            break
        end
    end
    return client
end)

return protect.protect_return(ServerPipe)