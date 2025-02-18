local function get(path)
    if not _G["/$p"] then
        return
    end

    return _G["/$p"][path]
end

local server_echo = get("server:modules/multiplayer/server/server_echo.lua")
local matches = get("server:modules/multiplayer/server/server_matches.lua")
local protocol = get("server:modules/lib/public/protocol.lua")

local function upd(blockid, x, y, z, playerid)
    if not server_echo then
        server_echo = get("server:modules/multiplayer/server/server_echo.lua")
        matches = get("server:modules/multiplayer/server/server_matches.lua")
        protocol = get("server:modules/lib/public/protocol.lua")
        return
    end

    local pseudo_packet = {
        type_packet = "protocol.ClientMsg.RequestChunk",
        x = math.floor(x / 16),
        z = math.floor(z / 16)
    }

    server_echo.put_event(
        function (client)
            matches.client_online_handler:switch(protocol.ClientMsg.RequestChunk, pseudo_packet, client)
        end
    )
end


function on_block_placed( ... )
    upd(...)
end

function on_block_broken( ... )
    upd(...)
end
