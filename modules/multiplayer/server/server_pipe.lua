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
                    local success, packet = pcall(function()
                        return protocol.parse_packet("client", function (len) return client.network:recieve_bytes(len) end)
                    end)

                    if success and packet then
                        List.pushright(client.received_packets, packet)
                        received_any = true
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
            matches.general_fsm:handle_event(client, packet)
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
        events.emit("server:client_pipe_start", client)
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