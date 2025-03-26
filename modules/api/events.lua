local function get(path)
    if not _G["/$p"] then
        return
    end

    return _G["/$p"][path]
end

local protocol = require "lib/public/protocol"
local server_echo = start_require("multiplayer/server/server_echo")

local module = {}
local handlers = {}

function module.tell(pack, event, client, bytes)
    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.PackEvent, pack, event, bytes))

    client.network:send(buffer.bytes)
end

function module.echo(pack, event, bytes)
    server_echo.put_event(function(client)
        local buffer = protocol.create_databuffer()
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.PackEvent, pack, event, bytes))
        client.network:send(buffer.bytes)
    end)
end

function module.on(pack, event, func)
    local pack_handlers = table.set_default(handlers, pack, {})
    local pack_handler_events = table.set_default(pack_handlers, event, {})

    table.insert(pack_handler_events, func)
end

function module.__emit__(pack, event, bytes, client)
    table.set_default(handlers, pack, {})
    table.set_default(handlers[pack], event, {})

    for _, func in ipairs(handlers[pack][event]) do
        func(client, bytes)
    end
end

return module
