local protocol = require "lib/public/protocol"
local server_echo = require "multiplayer/server/server_echo"

local module = {}

function module.tell(pack, event, client, bytes)
    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.PackEvent, pack, event, bytes))
    client.network:send(buffer.bytes)
end

function module.echo(pack, event, bytes)
    server_echo.put_event(function (client)
        local buffer = protocol.create_databuffer()
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.PackEvent, pack, event, bytes))
        client.network:send(buffer.bytes)
    end)
end

return module