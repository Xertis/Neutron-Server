local protocol = import "net/protocol/protocol"
local server_echo = import "lib/flow/server_echo"
local chunks_manager = import "core/sandbox/managers/chunks"
local EntityObserver = import "core/sandbox/classes/entity_observer"

local module = {}
local reg_entities = {}
local notificated_entities = {}


function module.register(entity_name, config, spawn_handler)
    if config.models then
        local new_models = {}
        for index, value in pairs(config.models) do
            new_models[tonumber(index)] = value
            logger.log("Entity model indexes must be number", "W")
        end
        config.models = new_models
    end

    reg_entities[entity_name] = {
        config = config,
        spawn_handler = spawn_handler
    }
    logger.log(string.format('The entity "%s" is registered.', entity_name))
end

function module.get_reg_config(entity_name)
    return reg_entities[entity_name]
end

function module.unload_entity(player, uid)
    player.entity_observers[uid] = nil
end

function module.despawn_for_player(client, uid)
    local player_obj = client.player

    local observer = player_obj.entity_observers[uid]
    if observer then observer:despawn() end

    player_obj.entity_observers[uid] = nil
    client:push_packet(protocol.ServerMsg.EntityDespawn, { uid })
end

function module.despawn(uid)
    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.EntityDespawn, { uid }))

    server_echo.put_event(
        function(client)
            local observer = client.player.entity_observers[uid]
            if observer then
                client.player.entity_observers[uid] = nil
                client:queue_response(buffer.bytes)
                observer:despawn()
            end
        end
    )
end

function module.binding(client)
    local player_obj = client.player
    local pid = player_obj.pid
    local player_pos = { player.get_pos(pid) }

    for _, uid in pairs(entities.get_all_in_radius(player_pos, player_obj.view_distance * 16)) do
        if player_obj.entity_observers[uid] then goto continue end

        local entity = entities.get(uid)
        if not entity then goto continue end

        local id = entity:def_index()
        local str_id = entity:def_name()
        local entity_pos = entity.transform:get_pos()

        if not chunks_manager.is_loaded(player_obj, math.floor(entity_pos[1] / 16), math.floor(entity_pos[3] / 16)) then
            goto continue
        end

        if PLAYER_ENTITY_ID == id then
            local entity_pid = entity:get_player()
            if entity_pid == ROOT_PID or entity_pid == pid or player.is_suspended(entity_pid) then
                goto continue
            end
        end

        local info = reg_entities[str_id] or {}
        local config = info.config

        if not config then
            if not table.has(notificated_entities, str_id) then
                logger.log("Spawn of an unregistered entity: " .. str_id)
                table.insert(notificated_entities, str_id)
            end
            goto continue
        end

        player_obj.entity_observers[uid] = EntityObserver.new(client, uid, config)

        ::continue::
    end
end

function module.update(client)
    local player_obj = client.player

    for uid, observer in pairs(player_obj.entity_observers) do
        local entity = observer.entity
        local entity_pos = entity.transform:get_pos()
        if entities.get(observer.uid) and chunks_manager.is_loaded(
                player_obj,
                math.floor(entity_pos[1] / 16),
                math.floor(entity_pos[3] / 16
                )) then
            observer:process()
        else
            module.despawn_for_player(client, uid)
        end
    end
end

function module.process(client)
    module.binding(client)
    module.update(client)
end

return module
