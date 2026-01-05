local protocol = require "multiplayer/protocol-kernel/protocol"
local switcher = require "lib/public/common/switcher"
local protect = require "lib/private/protect"
local sandbox = require "lib/private/sandbox/sandbox"
local http = require "server:lib/private/http/httprequestparser"

local function send_responce(client, responce)
    client:queue_response(utf8.tobytes(responce))
end

local matches = switcher.new(function(packet, client)
    local error = string.format("Path '%s' does not exist.", packet.request.path)
    logger.log(string.format('http 404 error: "%s", additional information in server.log', error))
    logger.log(json.tostring(packet), "E", true)

    local responce = http.buildResponse(404, {
        message = error
    })
    send_responce(client, responce)
end)

matches:add_case("/status", function (packet, client)
    logger.log("Sending the status...")
    local icon = nil

    if file.exists(USER_ICON_PATH) then
        icon = file.read_bytes(USER_ICON_PATH)
    else
        icon = file.read_bytes(DEFAULT_ICON_PATH)
    end

    local query = packet.request.query or {}

    local friends_list = query.friends_list or {}
    local players = table.keys(sandbox.get_players())
    local friends_states = {}

    for indx, friend in ipairs(friends_list) do
        friends_states[indx] = table.has(players, friend)
    end

    local packs = pack.get_installed()
    local plugins = table.freeze_unpack(CONFIG.game.plugins)

    table.filter(packs, function(_, p)
        if p == "server" or table.has(plugins, p) then
            return false
        end
        return true
    end)

    local status = {
        short_desc = CONFIG.server.short_description or '',
        description = CONFIG.server.description or '',
        favicon = base64.encode(icon),
        friends_states = friends_states,
        engine_version = CONFIG.server.version,
        protocol_reference = "Neutron",
        protocol_version = protocol.Version,

        neutron_version = SERVER_VERSION,
        api_version = API_VERSION,

        max = CONFIG.server.max_players,
        online = #players,

        plugins = plugins,
        content_packs = packs
    }

    local responce = http.buildResponse(200, status)
    send_responce(client, responce)
end)

return protect.protect_return(matches)