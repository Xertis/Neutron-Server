local protocol = require "lib/public/protocol"
local matcher = require "lib/public/common/matcher"
local protect = require "lib/private/protect"
local sandbox = require "lib/private/sandbox/sandbox"
local account_manager = require "lib/private/accounts/account_manager"

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
        local buffer = protocol.create_databuffer()

        local account = account_manager.login(packet.username)

        if not account then
            return
        end

        local account_player = sandbox.join_player(account)

        local rules = CONFIG.roles[account.role]

        local DATA = {
            account_player.pid,
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

        local x, y, z = player.get_pos(account_player.pid)
        local yaw, pitch = 0, 0
        DATA = {x, y, z, yaw, pitch}

        buffer = protocol.create_databuffer()
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.SynchronizePlayerPosition, unpack(DATA)))
        client.network:send(buffer.bytes)
        client:set_active(true)
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

---------

matches.block_update = matcher.new(
    function (values)
        print("SET BLOCK")
        local packet = values[1]

        local block = {
            x = packet.x,
            y = packet.y,
            z = packet.z,
            states = packet.block_state,
            id = packet.block_id
        }

        sandbox.place_block(block)
    end
)

matches.block_update:add_match(
    function (val)
        if val.packet_type == protocol.ClientMsg.BlockUpdate then
            return true
        end
    end
)

---------

matches.request_chunk = matcher.new(
    function (values)
        print("RETURN CHUNK")
        local packet = values[1]
        local client = matches.request_chunk.default_data
        local chunk = sandbox.get_chunk({x = packet.x, z = packet.z})

        if not chunk then
            return
        end

        local buffer = protocol.create_databuffer()

        local DATA = {
            packet.x,
            packet.z,
            chunk
        }

        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.ChunkData, unpack(DATA)))
        client.network:send(buffer.bytes)
    end
)

matches.request_chunk:add_match(
    function (val)
        if val.packet_type == protocol.ClientMsg.RequestChunk then
            return true
        end
    end
)

return protect.protect_return(matches)