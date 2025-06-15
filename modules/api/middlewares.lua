local protocol = start_require "multiplayer/protocol-kernel/protocol"

local server_matches = start_require("multiplayer/server/server_matches")
local switcher = server_matches.client_online_handler

local module = {
    packets = {
        ServerMsg = protocol.ServerMsg,
        ClientMsg = protocol.ClientMsg
    },
    receive = {},
    send = {}
}

function module.receive.add_middleware(packet_type, middleware)
    if type(middleware) ~= "function" then
        return error("Incorrect argument type")
    end
    switcher:add_middleware(packet_type, middleware)
end

function module.receive.add_general_middleware(middleware)
    if type(middleware) ~= "function" then
        return error("Incorrect argument type")
    end
    switcher:add_general_middleware(middleware)
end

local packets_middlewares = {}
function module.send.add_middleware(packet_type, middleware)
    local middlewares = table.set_default(packets_middlewares, packet_type, {})

    table.insert(middlewares, middleware)
end

local general_middlewares = {}
function module.send.add_general_middleware(middleware)
    table.insert(general_middlewares, middleware)
end

local function middlewares_process(client_or_server, packet_type, ...)
    for _, middleware in ipairs(packets_middlewares[packet_type] or {}) do
        if not middleware(packet_type, table.deep_copy({...})) then
            return false
        end
    end

    for _, middleware in ipairs(general_middlewares) do
        if not middleware(packet_type, table.deep_copy({...})) then
            return false
        end
    end

    return true
end

local build_packet = protocol.build_packet
protocol["build_packet"] = functions.set_middlewares(build_packet, {middlewares_process})

return module