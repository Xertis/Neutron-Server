local protocol = require "multiplayer/protocol-kernel/protocol"
local switcher = require "lib/public/common/switcher"
local protect = require "lib/private/protect"
local sandbox = require "lib/private/sandbox/sandbox"
local account_manager = require "lib/private/accounts/account_manager"
local chat = require "multiplayer/server/chat/chat"
local timeout_executor = require "lib/private/common/timeout_executor"
local echo = require "multiplayer/server/server_echo"
local api_events = require "api/v1/events"
local api_env = require "api/v1/env"
local entities_manager = require "lib/private/entities/entities_manager"
local lib = require "lib/private/min"
local mfsm = require "lib/public/common/multifsm"

local hashed_packs = nil

local matches = {
    general_fsm = mfsm.new(),
    status_fsm = mfsm.new(),
    joining_fsm = mfsm.new(),
    client_online_handler = switcher.new(function (...)
        local values = {...}
        print(json.tostring(values[1]))
    end)
}

matches.actions = {}

local function check_mods(client_hashes)
    local packs = pack.get_installed()
    local plugins = table.freeze_unpack(CONFIG.game.plugins)
    table.filter(packs, function(_, p)
        return not (p == "server" or table.has(plugins, p))
    end)

    local temp = {}
    for i = 1, #client_hashes, 2 do
        temp[client_hashes[i]] = client_hashes[i + 1]
    end
    client_hashes = temp

    if not hashed_packs then
        hashed_packs = {}
        for _, pack_name in ipairs(packs) do
            hashed_packs[pack_name] = lib.hash.hash_mods({pack_name})
        end
    end

    local incorrect = {}
    local i = 1

    for pack_name, hash in pairs(hashed_packs) do
        if hash ~= client_hashes[pack_name] then
            table.insert(incorrect, string.format("\n%s: %s", i, pack_name))
            i = i + 1
        end
        client_hashes[pack_name] = nil
    end

    for pack_name, _ in pairs(client_hashes) do
        table.insert(incorrect, string.format("\n%s: %s", i, pack_name))
        logger.log(string.format('The account has a modified client and is trying to add "%s" pack.', pack_name), '!')
        i = i + 1
    end

    local error_msg = table.concat(incorrect)
    return error_msg == '', error_msg
end


function matches.actions.Disconnect(client, reason)
    if client.player then
        entities_manager.clear_pid(client.player.pid)
    end

    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.Disconnect, reason))
    client.network:send(buffer.bytes)
    client:kick()
end

--- FSM

matches.general_fsm:add_state("idle", {
    on_event = function(client, event)
        if event.packet_type == protocol.ClientMsg.HandShake then
            if event.protocol_version ~= protocol.Version then
                return "idle"
            end

            if event.next_state == protocol.States.Status then
                matches.status_fsm:set_data(client, "friends_list", event.friends_list)
                matches.status_fsm:transition_to(client, "awaiting_status_request")
                return "status"
            end

            if event.next_state == protocol.States.Login then
                matches.joining_fsm:transition_to(client, "awaiting_join_game")
                return "joining"
            end
        end
    end
})

matches.general_fsm:add_state("status", {
    on_event = function (client, event)
        matches.status_fsm:handle_event(client, event)
    end
})

matches.general_fsm:add_state("joining", {
    on_event = function (client, event)
        matches.joining_fsm:handle_event(client, event)
    end
})

matches.status_fsm:add_state("awaiting_status_request", {
    on_event = function(client, event)
        if event.packet_type == protocol.ClientMsg.StatusRequest then
            return "sending_status"
        end
    end
})

matches.status_fsm:add_state("sending_status", {
    on_enter = function(client)
        logger.log("The expected package has been received, sending the status...")
        local buffer = protocol.create_databuffer()
        local icon = nil

        if file.exists(USER_ICON_PATH) then
            icon = file.read_bytes(USER_ICON_PATH)
        else
            icon = file.read_bytes(DEFAULT_ICON_PATH)
        end

        local friends_list = matches.status_fsm:get_data(client, "friends_list") or {}
        local players = table.keys(sandbox.get_players())
        local friends_states = {}

        for indx, friend in ipairs(friends_list) do
            friends_states[indx] = table.has(players, friend)
        end

        local STATUS = {
            CONFIG.server.short_description or '',
            CONFIG.server.description or '',
            icon,
            friends_states,
            CONFIG.server.version,
            "Neutron",
            protocol.data.version,
            CONFIG.server.max_players,
            #players
        }

        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.StatusResponse, unpack(STATUS)))
        client.network:send(buffer.bytes)
        logger.log("Status has been sent")

        client:kick()
        matches.status_fsm:clear(client)
        matches.general_fsm:transition_to(client, "idle")
    end
})

matches.joining_fsm:add_state("awaiting_join_game", {
    on_event = function(client, event)
        if event.packet_type == protocol.ClientMsg.JoinGame then
            matches.joining_fsm:set_data(client, "join_game", event)
            return "sending_packs_list"
        end
    end
})

matches.joining_fsm:add_state("sending_packs_list", {
    on_enter = function(client)
        local buffer = protocol.create_databuffer()

        local packs = pack.get_installed()
        local plugins = table.freeze_unpack(CONFIG.game.plugins)

        table.filter(packs, function (_, p)
            if p == "server" or table.has(plugins, p) then
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

matches.joining_fsm:add_state("awaiting_packs_hashes", {
    on_event = function(client, event)
        if event.packet_type == protocol.ClientMsg.PacksHashes then
            matches.joining_fsm:set_data(client, "packs_hashes", event)
            return "joining"
        end
    end
})

matches.joining_fsm:add_state("joining", {
    on_enter = function (client)
        local function close()
            matches.joining_fsm:clear(client)
            matches.general_fsm:transition_to(client, "idle")
        end

        local packet = matches.joining_fsm:get_data(client, "join_game")
        local hashes = matches.joining_fsm:get_data(client, "packs_hashes")
        local buffer = nil

        local account = account_manager.login(packet.username)
        local hash_status, hash_reason = check_mods(hashes.packs)

        if not hash_status and not CONFIG.server.dev_mode then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "Inconsistencies in mods:" .. hash_reason)
            close()
            return
        elseif not lib.validate.username(packet.username) then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "Incorrect user name")
            close()
            return
        elseif not account then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "Not found or unable to create an account")
            close()
            return
        elseif #table.keys(sandbox.get_players()) >= CONFIG.server.max_players then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "The server is full")
            close()
            return
        elseif (not table.has(table.freeze_unpack(CONFIG.server.whitelist), packet.username) and #table.freeze_unpack(CONFIG.server.whitelist) > 0) then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "You are not on the whitelist")
            close()
            return
        elseif (not table.has(table.freeze_unpack(CONFIG.server.whitelist_ip), client.address) and #table.freeze_unpack(CONFIG.server.whitelist_ip) > 0) then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "You are not on the whitelist")
            close()
            return
        elseif table.has(table.freeze_unpack(CONFIG.server.blacklist), packet.username) then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "You're on the blacklist")
            close()
            return
        elseif sandbox.get_players()[packet.username] ~= nil then
            logger.log("JoinSuccess has been aborted")
            matches.actions.Disconnect(client, "A player with that name is already online")
            close()
            return
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
            array_rules,
            math.clamp(CONFIG.server.chunks_loading_distance, 0, 255)
        }

        buffer = protocol.create_databuffer()
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.JoinSuccess, unpack(DATA)))
        client.network:send(buffer.bytes)
        logger.log("JoinSuccess has been sended")

        ---

        local state = sandbox.get_player_state(account_player)
        account_player.region_pos = {x = math.floor(state.x / 32), z = math.floor(state.z / 32)}
        client:set_active(true)

        timeout_executor.push(
            function (_client, x, y, z, yaw, pitch, noclip, flight, is_last)
                local _DATA = {
                    pos = {x = x, y = y, z = z},
                    rot = {yaw = yaw, pitch = pitch},
                    cheats = {noclip = noclip, flight = flight}
                }

                local buf = protocol.create_databuffer()
                buf:put_packet(protocol.build_packet("server", protocol.ServerMsg.SynchronizePlayerPosition, _DATA))
                _client.network:send(buf.bytes)

                if is_last then
                    _client.player.is_teleported = true
                    events.emit("server:player_ground_landing", _client)
                end
            end,
            {client, state.x, state.y, state.z, state.yaw, state.pitch, state.noclip, state.flight}, 3
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

        local data = sandbox.get_inventory(account_player)
        local inv, slot = data.inventory, data.slot

        buffer = protocol.create_databuffer()
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.PlayerInventory, inv))
        client.network:send(buffer.bytes)

        buffer = protocol.create_databuffer()
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.PlayerHandSlot, slot))
        client.network:send(buffer.bytes)

        ---
        events.emit("server:client_connected", client)

        if not CONFIG.server.password_auth then
            client.account.is_logged = true
            close()
            return
        end

        if account.password == nil then
            chat.tell("Please register using the command /register <password> <confirm password> to secure your account.", client)
        elseif not account.is_logged then
            chat.tell("Please log in using the command /login <password> to access your account.", client)
        end

        close()
    end
})

matches.general_fsm:set_default_state("idle")

--- CASES

matches.client_online_handler:add_case(protocol.ClientMsg.PlayerCheats, (
    function (packet, client)

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
    function (packet, client)

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
    function (packet, client)

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
    function (packet, client)

        if not client.account or not client.account.is_logged or not client.player.is_teleported then
            return
        end

        client.player.region_pos = {x = packet.x, z = packet.z}
    end
))

---------

matches.client_online_handler:add_case(protocol.ClientMsg.ChatMessage, (
    function (packet, client)

        if not client.player then
            return
        end

        local player = sandbox.get_player(client.player)
        local message = string.format("[%s] %s", player.username, packet.message)
        local state = chat.command(packet.message, client)
        if state == false then
            chat.echo(message)
        end
    end
))

---------

matches.client_online_handler:add_case(protocol.ClientMsg.Disconnect, (
    function (packet, client)

        if not client.account then
            return
        end

        local account = client.account
        local message = string.format("[%s] %s", account.username, "left the game")
        account_manager.leave(account)

        chat.echo(message)

        local pid = client.player.pid
        local username = client.player.username

        entities_manager.clear_pid(pid)

        local buffer = protocol.create_databuffer()
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.PlayerListRemove, username, pid))
        events.emit("server:client_disconnected", client)

        echo.put_event(
            function (c)
                c.network:send(buffer.bytes)
            end, client
        )
    end
))

--------

local function chunk_responce(packet, client, is_timeout)
    local chunk_pos = {x = packet.x, z = packet.z}

    if not client.account.is_logged then
        local queue = table.set_default(client.meta, "chunks_queue", {})
        table.merge(queue, {packet.x, packet.z})
        return
    end

    local chunk = sandbox.get_chunk(chunk_pos)

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

local function chunks_responce_optimizate(packet, client)
    local chunks_packet = packet.chunks
    local chunks_list = {}

    if not chunks_packet then
        chunks_packet = table.set_default(client.meta, "chunks_queue", {})

        if not chunks_packet then return end
    end

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
    function (packet, client)

        local x, y, z = packet.x, packet.y, packet.z

        local block_id = block.get(x, y, z)
        local block_name = block.name(block_id)
        events.emit(block_name .. ".interact", x, y, z, client.player.pid)
        events.emit("server:block_interact", block_id, x, y, z, client.player.pid)
    end
))

matches.client_online_handler:add_case(protocol.ClientMsg.BlockRegionInteract, (
    function (packet, client)

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
    function (packet, client)

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
    function (packet, client)

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
    function (packet, client)

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
    function (packet, client)

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
    function (packet, client)

        api_events.__emit__(packet.pack, packet.event, packet.bytes, client)
    end
))

matches.client_online_handler:add_case(protocol.ClientMsg.PackEnv, (
    function (packet, client)

        api_env.__env_update__(packet.pack, packet.env, packet.key, packet.value)
    end
))

matches.client_online_handler:add_case(protocol.ClientMsg.KeepAlive, (
    function (packet, client)

        local challenge = packet.challenge

        local wait_time = time.uptime() - client.ping.last_upd
        client.ping.ping = wait_time * 1000
    end
))

matches.client_online_handler:add_case(protocol.ClientMsg.PlayerInventory, (
    function (packet, client)
        if not client.account or not client.account.is_logged or not client.player.is_teleported then
            return
        end

        sandbox.set_inventory(client.player, packet.inventory)
    end
))

matches.client_online_handler:add_case(protocol.ClientMsg.PlayerHandSlot, (
    function (packet, client)
        if not client.account or not client.account.is_logged or not client.player.is_teleported then
            return
        end

        sandbox.set_selected_slot(client.player, packet.slot)
    end
))

matches.client_online_handler:add_case(protocol.ClientMsg.EntitySpawnTry, (
    function (packet, client)
        local name = entities.def_name(packet.entity_def)
        local conf = entities_manager.get_reg_config(name) or {}

        if conf.spawn_handler then
            conf.spawn_handler(name, packet.args, client)
        end
    end
))



return protect.protect_return(matches)