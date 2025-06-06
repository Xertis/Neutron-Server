local protocol = start_require "server:lib/public/protocol"
local server_echo = start_require "server:multiplayer/server/server_echo"

local module = {
    ServerMsg = protocol.ServerMsg,
    protocol = json.parse(file.read("server:default_data/protocol/protocol.json"))
}

function module.tell(client, packet_type, data)
    if protocol.ServerMsg[packet_type] == nil then
        error("Invalid packet type")
        return
    end

    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", packet_type, unpack(data)))
    client.network:send(buffer.bytes)
end

function module.echo(packet_type, data)
    if protocol.ServerMsg[packet_type] == nil then
        error("Invalid packet type")
        return
    end

    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", packet_type, unpack(data)))

    server_echo.put_event(
        function (client)
            if client.active ~= true then
                return
            end

            client.network:send(buffer.bytes)
        end
    )
end

return module