local protocol = require "lib/public/protocol"

local server_matches = start_require("multiplayer/server/server_matches")
local switcher = server_matches.client_online_handler

local module = {
    packets = {
        ServerMsg = protocol.ServerMsg,
        ClientMsg = protocol.ClientMsg
    }
}

function module.add_middleware(packet_type, middleware)
    if type(middleware) ~= "function" then
        return error("Incorrect argument type")
    end
    switcher:add_middleware(packet_type, middleware)
end

function module.add_general_middleware(middleware)
    if type(middleware) ~= "function" then
        return error("Incorrect argument type")
    end
    switcher:add_general_middleware(middleware)
end

return module