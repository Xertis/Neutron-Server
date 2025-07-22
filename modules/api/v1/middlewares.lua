local protocol = require "multiplayer/protocol-kernel/protocol"

local server_matches = start_require("multiplayer/server/server_matches")
local switcher = server_matches.client_online_handler

local fsm_middlewares = {}
local fsm_general_middlewares = {}

local module = {
    packets = {
        ServerMsg = protocol.ServerMsg,
        ClientMsg = protocol.ClientMsg
    },
    receive = {}
}

function module.receive.add_middleware(packet_type, middleware)
    if type(middleware) ~= "function" then
        return error("Incorrect argument type")
    end
    local status = switcher:add_middleware(packet_type, middleware)

    if not status then
        table.insert( table.set_default(fsm_middlewares, packet_type, {}), middleware )
    end
end

function module.receive.add_general_middleware(middleware)
    if type(middleware) ~= "function" then
        return error("Incorrect argument type")
    end
    switcher:add_general_middleware(middleware)
    table.insert(fsm_general_middlewares, middleware)
end

function module.receive.__fsm_emit(packet_type, packet, client)
    local middlewares = {}
    table.merge(middlewares, fsm_middlewares[packet_type] or {})
    table.merge(middlewares, fsm_general_middlewares)

    for _, middleware in ipairs(middlewares) do
        local status = middleware(table.deep_copy(packet), client)

        if not status then
            return false
        end
    end

    return true
end

return module