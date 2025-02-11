local protocol = require "lib/public/protocol"
local matcher = require "lib/public/common/matcher"
local protect = require "lib/private/protect"
local sandbox = require "lib/private/sandbox/sandbox"
local sand_player = require "lib/private/sandbox/classes/player"

local matches = {}

matches.status_request = matcher.new(
    function ()
        local client = matches.status_request.default_data
        logger.log("The expected package has been received, sending the status...")
        local buffer = protocol.create_databuffer()
        local icon = nil

        if file.exists(USER_ICON_PATH) then
            icon = file.read_bytes(USER_ICON_PATH)
        else
            icon = file.read_bytes(DEFAULT_ICON_PATH)
        end

        local players = {}

        local STATUS = {
            CONFIG.server.name,
            icon,
            CONFIG.game.version,
            protocol.data.version,
            players,
            CONFIG.game.worlds[CONFIG.game.main_world].seed,
            CONFIG.server.max_players,
            #players
        }

        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.StatusResponse, unpack(STATUS)))
        client.network:send(buffer.bytes)
        logger.log("Status has been sended")
    end
)

matches.status_request:add_match(
    function (val)
        if val.packet_type == protocol.ClientMsg.HandShake and val.next_state == protocol.States.Status then
            return true
        end
    end
)
matches.status_request:add_match(
    function (val)
        if val.packet_type == protocol.ClientMsg.StatusRequest then
            return true
        end
    end
)

---------

matches.logging = matcher.new(
    function (values)
        local client = matches.status_request.default_data
        local packet = values[2]
        logger.log(string.format('Player "%s" is logged in', packet.username))
        local buffer = protocol.create_databuffer()

        local client_player = sand_player.new(packet.username)
        sandbox.join_player(client_player)

        local rules = CONFIG.roles[client_player.role]

        local DATA = {
            client_player.pid,
            world.get_day_time(),
            rules.cheat_commands,
            rules.content_access,
            rules.flight,
            rules.noclip,
            rules.attack,
            rules.destroy,
            rules.cheat_movement,
            rules.debug_cheats,
            rules.fast_interaction
        }

        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.JoinSuccess, unpack(DATA)))
        client.network:send(buffer.bytes)
        logger.log("JoinSuccess has been sended")

        local x, y, z = player.get_pos(client_player.pid)
        local yaw, pitch = 0, 0
        DATA = {x, y, z, yaw, pitch}

        buffer = protocol.create_databuffer()
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.SynchronizePlayerPosition, unpack(DATA)))
        client.network:send(buffer.bytes)
    end
)

matches.logging:add_match(
    function (val)
        if val.packet_type == protocol.ClientMsg.HandShake and val.next_state == protocol.States.Login then
            return true
        end
    end
)
matches.logging:add_match(
    function (val)
        if val.packet_type == protocol.ClientMsg.JoinGame then
            return true
        end
    end
)

return protect.protect_return(matches)