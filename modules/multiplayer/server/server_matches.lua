local protocol = require "lib/public/protocol"
local matcher = require "lib/public/common/matcher"
local switcher = require "lib/public/common/switcher"
local protect = require "lib/private/protect"
local sandbox = require "lib/private/sandbox/sandbox"
local account_manager = require "lib/private/accounts/account_manager"
local chat = require "multiplayer/server/chat/chat"
local timeout_executor = require "lib/private/common/timeout_executor"
local echo = require "multiplayer/server/server_echo"
local api_events = require "api/events"
local lib = require "lib/private/min"

local hashed_packs = nil

local matches = {
    client_online_handler = switcher.new(function (...)
        local values = {...}
        print(json.tostring(values[1]))
    end)
}

matches.actions = {}

local function check_mods(client_hashes)
    local packs = pack.get_installed()

    table.filter(packs, function (_, p)
        if p == "server" then
            return false
        end
        return true
    end)

    if not hashed_packs then
        hashed_packs = {}
        for i, pack in ipairs(packs) do
            table.insert(hashed_packs, pack)
            table.insert(hashed_packs, lib.hash.hash_mods({pack}))
        end
    end

    return table.equals(hashed_packs, client_hashes)
end


function matches.actions.Disconnect(client, reason)
    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.Disconnect, reason))
    client.network:send(buffer.bytes)
end

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
            CONFIG.server.version,
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
        local hashes = values[3].packs
        local buffer = protocol.create_databuffer()

        local account = account_manager.login(packet.username)

        if not check_mods(hashes) then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "Inconsistencies in mods found")
            return
        elseif not lib.validate.username(packet.username) then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "Incorrect user name")
            return
        elseif not account then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "Not found or unable to create an account")
            return
        elseif #table.keys(sandbox.get_players()) >= CONFIG.server.max_players then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "The server is full")
            return
        elseif (not table.has(table.freeze_unpack(CONFIG.server.whitelist), packet.username) and #table.freeze_unpack(CONFIG.server.whitelist) > 0) then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "You are not on the whitelist")
            return
        elseif table.has(table.freeze_unpack(CONFIG.server.blacklist), packet.username) then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "You're on the blacklist")
            return
        elseif sandbox.get_players()[packet.username] ~= nil then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "A player with that name is already online")
            return
        end

        local account_player = sandbox.join_player(account)
        client:set_account(account)
        client:set_player(account_player)

        local rules = account_manager.get_rules(account)

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

        ---

        local state = sandbox.get_player_state(account_player)
        DATA = {state.x, state.y, state.z, state.yaw, state.pitch}

        buffer = protocol.create_databuffer()
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.SynchronizePlayerPosition, unpack(DATA)))
        client.network:send(buffer.bytes)
        client:set_active(true)

        ---

        local message = string.format("[%s] %s", account_player.username, "join the game")
        chat.echo(message)

        ---

        DATA = {account_player.username, account_player.pid}
        echo.put_event(
            function (c)
                buffer = protocol.create_databuffer()
                buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.PlayerListAdd, unpack(DATA)))
                c.network:send(buffer.bytes)
            end,
        client)

        local player_online = sandbox.get_players()
        local player_keys = table.keys(player_online)

        table.map(player_keys, function (i, v)
            return {
                player_online[v].pid,
                player_online[v].username
            }
        end)

        buffer = protocol.create_databuffer()
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.PlayerList, player_keys))
        client.network:send(buffer.bytes)

        ---

        if not CONFIG.server.password_auth then
            client.account.is_logged = true
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
matches.logging:add_match(
    function (val)
        if val.packet_type == protocol.ClientMsg.PacksHashes then
            return true
        end
    end
)

---------

matches.packs = matcher.new(
    function ()
        local client = matches.status_request.default_data
        local buffer = protocol.create_databuffer()

        local packs = pack.get_installed()

        table.filter(packs, function (_, p)
            if p == "server" then
                return false
            end

            return true
        end)

        local DATA = packs

        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.PacksList, DATA))
        client.network:send(buffer.bytes)
    end
)

matches.packs:add_match(
    function (val)
        if val.packet_type == protocol.ClientMsg.HandShake and val.next_state == protocol.States.Login then
            return true
        end
    end
)
matches.packs:add_match(
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
        local client = values[2]

        if not client.account or not client.account.is_logged then
            return
        end

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

local function chunk_responce(...)
    local values = {...}
    local packet = values[1]
    local client = values[2]
    local is_timeout = values[3]

    local chunk = sandbox.get_chunk({x = packet.x, z = packet.z})

    if not chunk then
        if not is_timeout then
            timeout_executor.push(
                chunk_responce,
                {packet, client, true},
                30
            )
        end

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

    return true
end


matches.client_online_handler:add_case(protocol.ClientMsg.RequestChunk, chunk_responce)

---------

matches.client_online_handler:add_case(protocol.ClientMsg.PlayerPosition, (
    function (...)
        local values = {...}
        local packet = values[1]
        local client = values[2]

        if not client.account or not client.account.is_logged then
            return
        end

        sandbox.set_player_state(client.player, {
            x = packet.x,
            y = packet.y,
            z = packet.z,
            yaw = packet.yaw,
            pitch = packet.pitch
        })
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
        local client = values[2]

        if not client.account then
            return
        end

        local account = client.account
        local message = string.format("[%s] %s", account.username, "leave the game")
        account_manager.leave(account)

        chat.echo(message)

        local pid = client.player.pid
        local username = client.player.username

        local buffer = protocol.create_databuffer()
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.PlayerListRemove, username, pid))

        echo.put_event(
            function (c)
                c.network:send(buffer.bytes)
            end, client
        )
    end
))

--------

local function chunks_responce_optimizate(...)
    local values = {...}
    local chunks_packet = values[1].chunks
    local client = values[2]
    local chunks_list = {}

    for indx=1, #chunks_packet, 2 do
        local x, z = chunks_packet[indx], chunks_packet[indx+1]

        local chunk = sandbox.get_chunk({x = x, z = z})
        if chunk then
            table.insert(chunks_list, {x, z, chunk})
        else
            local pseudo_packet = {
                x = x,
                z = z,
            }

            chunk_responce(pseudo_packet, client)
        end
    end

    local buffer = protocol.create_databuffer()

    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.ChunksData, chunks_list))
    client.network:send(buffer.bytes)

    return true
end

matches.client_online_handler:add_case(protocol.ClientMsg.RequestChunks, chunks_responce_optimizate)

--------

matches.client_online_handler:add_case(protocol.ClientMsg.BlockInteract, (
    function (...)
        local values = {...}
        local packet = values[1]

        local x, y, z = packet.x, packet.y, packet.z

        local block_name = block.name(block.get(x, y, z))
        events.emit(block_name .. ".interact", x, y, z, 1)
        events.emit("server:block_interact", block.get(x, y, z), x, y, z, 1)
    end
))

--------

matches.client_online_handler:add_case(protocol.ClientMsg.PackEvent, (
    function (...)
        local values = {...}
        local packet = values[1]

        api_events.__emit__(packet.pack, packet.event, packet.bytes)
    end
))

return protect.protect_return(matches)