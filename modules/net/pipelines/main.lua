local Pipeline = import "lib/flow/async_pipeline"
local protocol = import "net/protocol/protocol"
local matches = import "net/handlers/main"
local ClientPipe = import "net/pipelines/client"
local List = import "lib/utils/list"
local interceptors = import "api/v2/interceptors"
local receiver = import "server:net/protocol/receiver"

local ServerPipe = Pipeline.new()

ServerPipe:add_middleware(function(client)
    local meta = client.meta
    local co = meta.receive_co

    if not co then
        meta.buffer = receiver.create_buffer()
        co = coroutine.create(function()
            local buffer = meta.buffer

            while true do
                local success, packet = pcall(protocol.parse_packet, "client", buffer)

                if success and packet then
                    List.pushright(client.received_packets, packet)
                else
                    if not success then
                        client:kick()
                        logger.log("Error while parsing packet: " .. tostring(packet) .. '\nClient disconnected', 'E')
                    end

                    coroutine.yield()
                end
            end
        end)
        meta.receive_co = co
    end

    receiver.recv(meta.buffer, client)
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
            local status = interceptors.receive.__process(packet, client)
            if status then matches.general_fsm:handle_event(client, packet) end
        elseif client.active == true then
            matches.client_online_handler:switch(packet.packet_type, packet, client)
        end
    end)

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

    local socket = client.socket
    while not List.is_empty(client.response_queue) do
        local packet = List.popleft(client.response_queue)
        local success, err = pcall(socket.send, socket, packet)
        if not success then
            logger.log("Error when sending a packet: " .. err, 'E')
            break
        end
    end

    return client
end)

return ServerPipe
