local Pipeline = require "lib/public/async_pipeline"
local protocol = require "multiplayer/protocol-kernel/protocol"
local protect = require "lib/private/protect"
local matches = require "multiplayer/server/server_matches"
local ClientPipe = require "multiplayer/server/client_pipe"
local List = require "lib/public/common/list"
local middlewares = require "api/v1/middlewares"

local ServerPipe = Pipeline.new()

ServerPipe:set_quota_function(function(client)
    local load = 0
    if client.active then
        load = load + 1
    end
    load = load + List.size(client.received_packets)
    load = load + List.size(client.response_queue)
    return load
end)

ServerPipe:add_middleware(function(ctx)
    local client = ctx.client

    if not client.meta.recieve_co then
        client.meta.recieve_co = coroutine.create(function()
            while true do
                local success, packet = pcall(protocol.parse_packet, "client",
                    function(len) return client.network:recieve_bytes(len) end)

                if success and packet then
                    List.pushright(client.received_packets, packet)
                    ctx.packets_read = (ctx.packets_read or 0) + 1
                elseif not success then
                    client:kick()
                    logger.log("Error while parsing packet: " .. packet, 'E')
                    return "break"
                else
                    break
                end
            end
        end)
    end

    if coroutine.status(client.meta.recieve_co) ~= "dead" then
        coroutine.resume(client.meta.recieve_co)
    end
end)


ServerPipe:add_middleware(function(ctx)
    local client = ctx.client
    if List.is_empty(client.received_packets) then return end

    local packet = List.popleft(client.received_packets)
    ctx.packets_processed = (ctx.packets_processed or 0) + 1

    local status, err = pcall(function()
        if not client.active then
            if middlewares.receive.__fsm_emit(packet.packet_type, packet, client) then
                matches.general_fsm:handle_event(client, packet)
            end
        else
            matches.client_online_handler:switch(packet.packet_type, packet, client, ctx.await)
        end
    end)

    if not status then
        client:kick()
        logger.log("Error while processing packet: " .. err, 'E')
        return "break"
    end
end)

ServerPipe:add_middleware(function(ctx)
    local client = ctx.client
    if client.active then
        events.emit("server:client_pipe_start", client)
        ClientPipe:process(client)
    end
end)

ServerPipe:add_middleware(function(ctx)
    local client = ctx.client
    if List.is_empty(client.response_queue) then return end

    local packet = List.popleft(client.response_queue)
    ctx.packets_sent = (ctx.packets_sent or 0) + 1

    local status, err = pcall(client.network.send, client.network, packet)
    if not status then
        logger.log("Error when sending a packet: " .. err, 'E')
    end
end)

return protect.protect_return(ServerPipe)