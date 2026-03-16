local Pipeline = require "lib/public/async_pipeline"
local protocol = require "multiplayer/protocol-kernel/protocol"
local protect = require "lib/private/protect"
local matches = require "multiplayer/server/handlers/http_matches"
local List = require "lib/public/common/list"
local interceptors = require "api/v2/interceptors"
local http = require "server:lib/private/http/httprequestparser"
local receiver = require "server:multiplayer/protocol-kernel/receiver"

local HttpPipe = Pipeline.new()

HttpPipe:add_middleware(function(client)
    local co = client.meta.recieve_co
    if not co then
        client.meta.buffer = receiver.create_buffer()
        co = coroutine.create(function()
            local buffer = client.meta.buffer
            while true do
                local received_any = false
                while true do
                    local success, packet = pcall(function()
                        return protocol.parse_query(buffer)
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

HttpPipe:add_middleware(function(client)
    if List.is_empty(client.received_packets) then
        return client
    end

    local packet = List.popleft(client.received_packets)

    local success, err = pcall(function()
        local status = interceptors.receive.__process(packet, client)
        if status then matches:switch(packet.path, packet, client) end
    end)

    if not success then
        client:kick()

        logger.log(string.format("http handler error: %s, additional information in server.log", err), "E")
        logger.log(debug.traceback(), "E", true)
        logger.log(json.tostring(packet), "E", true)
        client:queue_response(utf8.tobytes(
            http.buildResponse(500, {
                message = "Internal Server Error"
            })
        ))
    end

    return client, not List.is_empty(client.received_packets)
end)

HttpPipe:add_middleware(function(client)
    while not List.is_empty(client.response_queue) do
        local packet = List.popleft(client.response_queue)
        local success, err = pcall(function()
            client.socket:send(packet)
        end)
        if not success then
            logger.log("Error when sending a packet: " .. err, 'E')
            break
        end
    end

    return client
end)

return protect.protect_return(HttpPipe)
