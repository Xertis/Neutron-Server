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
    switcher:add_middleware(packet_type, middleware)
end

return module