local entities_api = import "api/v2/entities"
local text3d = import "api/v2/text3d"


entities_api.register(
    entities.def_name(PLAYER_ENTITY_ID),
    {
        on_client_spawn = function(_, uid)
            local entity = entities.get(uid)
            local pid = entity:get_player()
            if not pid or pid == -1 then return end

            local _, text = text3d.show({ 0, 1, 0 }, player.get_name(pid), {
                display = "projected",
                xray_opacity = 0.3,
                render_distance = 128,
                perspective = 0.0
            })

            text:set_entity(uid)
        end,
        standard_fields = {
            tsf_pos = {
                maximum_deviation = 0.5,
                evaluate_deviation = entities_api.eval.VectorNotEquals
            }
        },
        components = {
            ["base:player_animator"] = {
                maximum_deviation = 1,
                evaluate_deviation = entities_api.eval.NotEquals,
                provider = function()
                    return false
                end
            }
        },
        -- Рука
        models = {
            [3] = {
                maximum_deviation = 1,
                evaluate_deviation = entities_api.eval.NotEquals,
                provider = function(uid, key)
                    local entity = entities.get(uid)
                    local pid = entity:get_player()
                    if not pid or pid == -1 then return end

                    local id, _ = inventory.get(player.get_inventory(entity:get_player()))
                    if id == 0 then return "" end

                    return item.model_name(id)
                end
            },
        },
        matrix = {
            -- Туловище
            [1] = {
                maximum_deviation = 1,
                evaluate_deviation = entities_api.eval.VectorNotEquals,
                provider = function(uid, key)
                    local entity = entities.get(uid)
                    local pid = entity:get_player()
                    if not pid or pid == -1 then return end

                    local rx, ry, rz = player.get_rot(pid)
                    return mat4.rotate({ 0, 1, 0 }, rx)
                end
            },
            -- Голова
            [2] = {
                maximum_deviation = 1,
                evaluate_deviation = entities_api.eval.VectorNotEquals,
                provider = function(uid, key)
                    local entity = entities.get(uid)
                    local pid = entity:get_player()
                    if not pid or pid == -1 then return end

                    local rx, ry, rz = player.get_rot(pid)
                    return mat4.rotate({ 1, 0, 0 }, ry)
                end
            },
        },
    }
)
