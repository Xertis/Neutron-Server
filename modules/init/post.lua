local entities_api = import "api/v2/entities"

entities_api.register(
    entities.def_name(PLAYER_ENTITY_ID),
    {
        custom_fields = {
            pid = {
                maximum_deviation = 1,
                evaluate_deviation = entities_api.eval.NotEquals,
                provider = function(uid, field_name)
                    local entity = entities.get(uid)
                    return entity:get_player()
                end
            },
            name = {
                maximum_deviation = 1,
                evaluate_deviation = entities_api.eval.NotEquals,
                provider = function(uid, field_name)
                    local entity = entities.get(uid)
                    local pid = entity:get_player()
                    if not pid then return end
                    return player.get_name(pid)
                end
            },
            rot = {
                maximum_deviation = 1,
                evaluate_deviation = entities_api.eval.VectorNotEquals,
                provider = function(uid, field_name)
                    local entity = entities.get(uid)
                    local pid = entity:get_player()
                    if not pid then return end
                    return { player.get_rot(pid) }
                end
            },
            hand = {
                maximum_deviation = 1,
                evaluate_deviation = entities_api.eval.NotEquals,
                provider = function(uid, field_name)
                    local entity = entities.get(uid)
                    local pid = entity:get_player()
                    if not pid then return end

                    local current_invid, current_slot = player.get_inventory(pid)
                    local current_hand_item = inventory.get(current_invid, current_slot)
                    return current_hand_item
                end
            }
        },
        standard_fields = {
            tsf_pos = {
                maximum_deviation = 0.5,
                evaluate_deviation = entities_api.eval.NotEquals
            },
            tsf_rot = {
                maximum_deviation = 1,
                evaluate_deviation = entities_api.eval.NotEquals
            },
            tsf_size = {
                maximum_deviation = 1,
                evaluate_deviation = entities_api.eval.Never
            },
            body_size = {
                maximum_deviation = 1,
                evaluate_deviation = entities_api.eval.Never
            },
        },
        matrix = {
            [0] = {
                maximum_deviation = 1,
                evaluate_deviation = entities_api.eval.VectorNotEquals
            },
        },
    }
)
