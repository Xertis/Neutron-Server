local entities_manager = import "core/sandbox/managers/entities"

logger.log("Patching the in-memory engine before start")

--- Патчим сущностей

local entities_despawn = entities.despawn
entities["despawn"] = function(eid)
    entities_despawn(eid)
    entities_manager.despawn(eid)
end

if IS_HEADLESS then
    local skeletons_info = {
        textures = {},
        models = {},
        matrix = {}
    }

    __skeleton.set_texture = function(id, key, texture)
        table.set_default(skeletons_info.textures, id, {})[key] = texture
    end

    __skeleton.set_model = function(id, key, model)
        table.set_default(skeletons_info.models, id, {})[key] = model
    end

    __skeleton.set_matrix = function(id, key, matrix)
        table.set_default(skeletons_info.matrix, id, {})[key] = matrix
    end

    __skeleton.get_texture = function(id, key)
        local skeleton = skeletons_info.textures[id]
        if skeleton then
            return skeleton[key]
        end
    end

    __skeleton.get_model = function(id, key)
        local skeleton = skeletons_info.models[id]
        if skeleton then
            return skeleton[key]
        end
    end

    __skeleton.get_matrix = function(id, key)
        local skeleton = skeletons_info.matrix[id]
        if skeleton then
            return skeleton[key]
        end
    end
end

-- Патчим глобальные модули
import "api/v2/patched/patcher"
