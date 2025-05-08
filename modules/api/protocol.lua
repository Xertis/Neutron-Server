local protocol = start_require "lib/public/protocol"

local module = {
    ServerMsg = protocol.ServerMsg,
    protocol = json.parse(file.read("server:default_data/protocol.json"))
}

function module.send_packet(client, packet_type, data)
    if protocol.ServerMsg[packet_type] == nil then
        error("Invalid packet type")
        return
    end

    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", packet_type, unpack(data)))
    client.network:send(buffer.bytes)
end

return module