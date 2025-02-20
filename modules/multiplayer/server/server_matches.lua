local protocol = require "lib/public/protocol"
local matcher = require "lib/public/common/matcher"
local switcher = require "lib/public/common/switcher"
local protect = require "lib/private/protect"
local sandbox = require "lib/private/sandbox/sandbox"
local account_manager = require "lib/private/accounts/account_manager"
local chat = require "multiplayer/server/chat"

local matches = {
    client_online_handler = switcher.new(function (...)
        local values = {...}
        print(json.tostring(values[1]))
    end)
}

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

        local players = table.keys(sandbox.get_players())

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

        if not account or #table.keys(sandbox.get_players()) >= CONFIG.server.max_players or sandbox.get_players()[packet.username] ~= nil then
            logger.log("JoinSuccess has been aborted")
            return
        end

        local account_player = sandbox.join_player(account)
        client:set_account(account)
        client:set_player(account_player)

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

        local state = sandbox.get_player_state(account_player)
        DATA = {state.x, state.y, state.z, state.yaw, state.pitch}

        buffer = protocol.create_databuffer()
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.SynchronizePlayerPosition, unpack(DATA)))
        client.network:send(buffer.bytes)
        client:set_active(true)

        local message = string.format("[%s] %s", account_player.username, "join the game")
        chat.echo(message)

        if not CONFIG.server.password_auth then
            return
        end

        if account.password == nil then
            chat.tell("Please register using the command .register <password> <confirm password> to secure your account.", client)
        elseif not account.is_logged then
            chat.tell("Please log in using the command .login <password> to access your account.", client)
        end
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

matches.client_online_handler:add_case(protocol.ClientMsg.BlockUpdate, (
    function (...)
        local values = {...}
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
))

---------

matches.client_online_handler:add_case(protocol.ClientMsg.RequestChunk, (
    function (...)
        local values = {...}
        local packet = values[1]
        local client = values[2]
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
))

---------

matches.client_online_handler:add_case(protocol.ClientMsg.PlayerPosition, (
    function (...)
        local values = {...}
        local packet = values[1]
        local client = values[2]

        if not client.account then
            return
        end

        if client.account.is_logged then
            sandbox.set_player_state(client.player, {
                x = packet.x,
                y = packet.y,
                z = packet.z,
                yaw = packet.yaw,
                pitch = packet.pitch
            })
        end
    end
))

---------

matches.client_online_handler:add_case(protocol.ClientMsg.ChatMessage, (
    function (...)
        local values = {...}
        local packet = values[1]
        local client = values[2]

        if not client.player then
            return
        end

        local player = sandbox.get_player(client.player)
        local message = string.format("[%s] %s", player.username, packet.message)

        if packet.message[1] == '.' then
            chat.command(packet.message, client)
        else
            chat.echo(message)
        end
    end
))

---------

matches.client_online_handler:add_case(protocol.ClientMsg.Disconnect, (
    function (...)
        local values = {...}
        local packet = values[1]
        local client = values[2]

        if not client.account then
            return
        end

        local account = client.account
        local message = string.format("[%s] %s", account.username, "leave the game")
        account_manager.leave(account)

        chat.echo(message)
    end
))

return protect.protect_return(matches)