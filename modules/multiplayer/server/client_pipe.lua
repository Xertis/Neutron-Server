local Pipeline = require "lib/public/pipeline"
local protocol = require "lib/public/protocol"
local protect = require "lib/private/protect"

local ClientPipe = Pipeline.new()

--Отправляем игровое время
ClientPipe:add_middleware(function(client)

    local buffer = protocol.create_databuffer()

    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.TimeUpdate, world.get_day_time()))
    client.network:send(buffer.bytes)
    return client
end)

return protect.protect_return(ClientPipe)