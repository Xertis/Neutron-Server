local protocol = require "multiplayer/protocol-kernel/protocol"

local server_matches = start_require("multiplayer/server/server_matches")
local switcher = server_matches.client_online_handler

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
    switcher:add_middleware(packet_type, middleware)
end

function module.receive.add_general_middleware(middleware)
    if type(middleware) ~= "function" then
        return error("Incorrect argument type")
    end
    switcher:add_general_middleware(middleware)
end

return module