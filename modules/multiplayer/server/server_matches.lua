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
local api_env = require "api/env"
local lib = require "lib/private/min"
local mfsm = require "lib/public/common/multifsm"

local hashed_packs = nil

local matches = {
    fsm = mfsm.new(),
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

    local temp = {}
    for i=1, #client_hashes, 2 do
        temp[client_hashes[i]] = client_hashes[i+1]
    end
    client_hashes = temp

    if not hashed_packs then
        hashed_packs = {}
        for _, pack in ipairs(packs) do
            hashed_packs[pack] = lib.hash.hash_mods({pack})
        end
    end

    local incorrect = ''
    local i = 1

    for pack, hash in pairs(hashed_packs) do
        if hash ~= client_hashes[pack] then
            incorrect = incorrect .. string.format("\n%s: %s", i, pack)
            i = i + 1
        end
    end

    return incorrect == '', incorrect
end


function matches.actions.Disconnect(client, reason)
    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.Disconnect, reason))
    client.network:send(buffer.bytes)
end

--- FSM

matches.fsm:add_state("idle", {
    on_event = function(client, event)
        if event.packet_type ~= protocol.ClientMsg.HandShake then
            return
        end

        if event.next_state == protocol.States.Status then
            return "awaiting_status_request"
        elseif event.next_state == protocol.States.Login then
            return "awaiting_join_game"
        end
    end
})

matches.fsm:add_state("awaiting_status_request", {
    on_event = function(client, event)
        if event.packet_type == protocol.ClientMsg.StatusRequest then
            return "sending_status"
        end
    end
})

matches.fsm:add_state("awaiting_join_game", {
    on_event = function(client, event)
        if event.packet_type == protocol.ClientMsg.JoinGame then
            matches.fsm.client_data[client] = matches.fsm.client_data[client] or {}
            matches.fsm.client_data[client].join_game = event
            return "sending_packs_list"
        end
    end
})

matches.fsm:add_state("awaiting_packs_hashes", {
    on_event = function(client, event)
        if event.packet_type == protocol.ClientMsg.PacksHashes then
            matches.fsm.client_data[client] = matches.fsm.client_data[client] or {}
            matches.fsm.client_data[client].packs_hashes = event
            return "joining"
        end
    end
})

matches.fsm:add_state("sending_status", {
    on_enter = function(client)
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
        logger.log("Status has been sent")

        return "idle"
    end
})

matches.fsm:add_state("sending_packs_list", {
    on_enter = function(client)
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

        return "awaiting_packs_hashes"
    end
})

matches.fsm:add_state("joining", {
    on_enter = function (client)
        local values = matches.fsm.client_data[client]
        local packet = values.join_game
        local hashes = values.packs_hashes.packs
        local buffer = protocol.create_databuffer()

        local account = account_manager.login(packet.username)
        local hash_status, hash_reason = check_mods(hashes)

        if not hash_status and not CONFIG.server.dev_mode then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "Inconsistencies in mods:" .. hash_reason)
            return "idle"
        elseif not lib.validate.username(packet.username) then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "Incorrect user name")
            return "idle"
        elseif not account then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "Not found or unable to create an account")
            return "idle"
        elseif #table.keys(sandbox.get_players()) >= CONFIG.server.max_players then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "The server is full")
            return "idle"
        elseif (not table.has(table.freeze_unpack(CONFIG.server.whitelist), packet.username) and #table.freeze_unpack(CONFIG.server.whitelist) > 0) then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "You are not on the whitelist")
            return "idle"
        elseif table.has(table.freeze_unpack(CONFIG.server.blacklist), packet.username) then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "You're on the blacklist")
            return "idle"
        elseif sandbox.get_players()[packet.username] ~= nil then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "A player with that name is already online")
            return "idle"
        end

        local account_player = sandbox.join_player(account)
        client:set_account(account)
        client:set_player(account_player)

        local rules = account_manager.get_rules(account)
        local array_rules = {}

        for _, rule_name in pairs(table.freeze_unpack(rules.__keys)) do
            table.insert(array_rules, {rule_name, rules[rule_name]})
        end

        local DATA = {
            account_player.pid,
            time.day_time_to_uint16(world.get_day_time()),
            array_rules
        }

        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.JoinSuccess, unpack(DATA)))
        client.network:send(buffer.bytes)
        logger.log("JoinSuccess has been sended")

        ---

        local state = sandbox.get_player_state(account_player)
        DATA = {state.x, state.y, state.z, state.yaw, state.pitch, state.noclip, state.flight}
        account_player.region_pos = {x = math.floor(state.x / 32), z = math.floor(state.z / 32)}
        buffer = protocol.create_databuffer()
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.SynchronizePlayerPosition, unpack(DATA)))
        client.network:send(buffer.bytes)
        client:set_active(true)

        timeout_executor.push(
            function (_client, x, y, z, yaw, pitch, noclip, flight, is_last)
                local _DATA = {x, y, z, yaw, pitch, noclip, flight}
                local buf = protocol.create_databuffer()
                buf:put_packet(protocol.build_packet("server", protocol.ServerMsg.SynchronizePlayerPosition, unpack(_DATA)))
                _client.network:send(buf.bytes)

                if is_last then
                    _client.player.is_teleported = true
                end
            end,
            {client, state.x, state.y, state.z, state.yaw, state.pitch, state.noclip, state.flight}, 1
        )

        ---

        local message = string.format("[%s] %s", account_player.username, "join the game")
        chat.echo(message)

        ---

        local p_data = {account_player.username, account_player.pid}
        echo.put_event(
            function (c)
                buffer = protocol.create_databuffer()
                buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.PlayerListAdd, unpack(p_data)))
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
            return "idle"
        end

        if account.password == nil then
            chat.tell("Please register using the command .register <password> <confirm password> to secure your account.", client)
        elseif not account.is_logged then
            chat.tell("Please log in using the command .login <password> to access your account.", client)
        end

        return "idle"
    end
})

matches.fsm:set_default_state("idle")

--- CASES

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

matches.client_online_handler:add_case(protocol.ClientMsg.PlayerCheats, (
    function (...)
        local values = {...}
        local packet = values[1]
        local client = values[2]

        if not client.account or not client.account.is_logged or not client.player.is_teleported then
            return
        end

        sandbox.set_player_state(client.player, {
            noclip = packet.noclip,
            flight = packet.flight
        })
    end
))

matches.client_online_handler:add_case(protocol.ClientMsg.PlayerRotation, (
    function (...)
        local values = {...}
        local packet = values[1]
        local client = values[2]

        if not client.account or not client.account.is_logged or not client.player.is_teleported then
            return
        end

        sandbox.set_player_state(client.player, {
            yaw = packet.yaw,
            pitch = packet.pitch
        })
    end
))

matches.client_online_handler:add_case(protocol.ClientMsg.PlayerPosition, (
    function (...)
        local values = {...}
        local packet = values[1]
        local client = values[2]

        if not client.account or not client.account.is_logged or not client.player.is_teleported then
            return
        end

        local x, z = packet.pos.x, packet.pos.z

        x = x + client.player.region_pos.x * 32
        z = z + client.player.region_pos.z * 32

        sandbox.set_player_state(client.player, {
            x = x,
            y = packet.pos.y,
            z = z
        })
    end
))

matches.client_online_handler:add_case(protocol.ClientMsg.PlayerRegion, (
    function (...)
        local values = {...}
        local packet = values[1]
        local client = values[2]

        if not client.account or not client.account.is_logged or not client.player.is_teleported then
            return
        end

        client.player.region_pos = {x = packet.x, z = packet.z}
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
        local client = values[2]

        local x, y, z = packet.x, packet.y, packet.z

        local block_id = block.get(x, y, z)
        local block_name = block.name(block_id)
        events.emit(block_name .. ".interact", x, y, z, client.player.pid)
        events.emit("server:block_interact", block_id, x, y, z, client.player.pid)
    end
))

matches.client_online_handler:add_case(protocol.ClientMsg.BlockRegionInteract, (
    function (...)
        print("IN REGION")
        local values = {...}
        local packet = values[1]
        local client = values[2]

        local x, y, z = packet.x, packet.y, packet.z

        x = client.player.region_pos.x * 32 + x
        z = client.player.region_pos.z * 32 + z

        local block_id = block.get(x, y, z)
        local block_name = block.name(block_id)
        events.emit(block_name .. ".interact", x, y, z, client.player.pid)
        events.emit("server:block_interact", block_id, x, y, z, client.player.pid)
    end
))

--------

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

        sandbox.place_block(block, client.player.pid)
    end
))

matches.client_online_handler:add_case(protocol.ClientMsg.BlockRegionUpdate, (
    function (...)
        print("IN REGION")
        local values = {...}
        local packet = values[1]
        local client = values[2]

        if not client.account or not client.account.is_logged then
            return
        end

        local x, y, z = packet.x, packet.y, packet.z

        x = client.player.region_pos.x * 32 + x
        z = client.player.region_pos.z * 32 + z

        local block = {
            x = x,
            y = y,
            z = z,
            states = packet.block_state,
            id = packet.block_id
        }

        sandbox.place_block(block, client.player.pid)
    end
))

--------

matches.client_online_handler:add_case(protocol.ClientMsg.BlockDestroy, (
    function (...)
        local values = {...}
        local packet = values[1]
        local client = values[2]

        if not client.account or not client.account.is_logged then
            return
        end

        if table.has({0, -1}, block.get(packet.x, packet.y, packet.z)) then
            return
        end

        sandbox.destroy_block({x = packet.x, y = packet.y, z = packet.z}, client.player.pid)
    end
))

matches.client_online_handler:add_case(protocol.ClientMsg.BlockRegionDestroy, (
    function (...)
        print("IN REGION")
        local values = {...}
        local packet = values[1]
        local client = values[2]

        if not client.account or not client.account.is_logged then
            return
        end

        local x, y, z = packet.x, packet.y, packet.z

        x = client.player.region_pos.x * 32 + x
        z = client.player.region_pos.z * 32 + z

        if table.has({0, -1}, block.get(x, y, z)) then
            return
        end

        sandbox.destroy_block({x = x, y = y, z = z}, client.player.pid)
    end
))

--------

matches.client_online_handler:add_case(protocol.ClientMsg.PackEvent, (
    function (...)
        local values = {...}
        local packet = values[1]
        local client = values[2]

        api_events.__emit__(packet.pack, packet.event, packet.bytes, client)
    end
))

matches.client_online_handler:add_case(protocol.ClientMsg.PackEnv, (
    function (...)
        local values = {...}
        local packet = values[1]

        api_env.__env_update__(packet.pack, packet.env, packet.key, packet.value)
    end
))


return protect.protect_return(matches)