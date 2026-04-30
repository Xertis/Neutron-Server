local chunks_manager = import "core/sandbox/managers/chunks"

local module = {}

local TEXTS = {}

local NEXT_ID = 1

local function ensureText(id)
    if not TEXTS[id] then
        error 'undefined text'
    end
end

local function ensureVec3(vec)
    if type(vec) ~= "table" or #vec ~= 3 then
        error 'invalid vec3'
    end
end

function module.show(position, text, preset, extension)
    local id = NEXT_ID

    TEXTS[id] = {
        position = position,
        text = text,
        preset = preset,
        extension = extension,
        id = NEXT_ID,
        blind = {}
    }

    NEXT_ID = NEXT_ID + 1

    return id
end

function module.exists(id)
    return TEXTS[id] ~= nil
end

function module.hide(id)
    ensureText(id)
    TEXTS[id] = nil
end

function module.get_text(id)
    ensureText(id)
    return TEXTS[id].text
end

function module.set_text(id, text)
    ensureText(id)

    if not text then text = "" end

    TEXTS[id].text = text
end

function module.get_pos(id)
    ensureText(id)
    return TEXTS[id].position
end

function module.set_pos(id, position)
    ensureText(id)
    ensureVec3(position)

    TEXTS[id].position = position
end

function module.get_axis_x(id)
    ensureText(id)
    return TEXTS[id].axisX or { 1, 0, 0 }
end

function module.set_axis_x(id, axis)
    ensureText(id)
    ensureVec3(axis)
    TEXTS[id].axisX = axis
end

function module.get_axis_y(id)
    ensureText(id)
    return TEXTS[id].axisY or { 0, 1, 0 }
end

function module.set_axis_y(id, axis)
    ensureText(id)
    ensureVec3(axis)
    TEXTS[id].axisY = axis
end

function module.set_rotation(id, rotation)
    ensureText(id)

    if type(rotation) ~= "table" or #rotation ~= 16 then
        error 'invalid mat4'
    end

    TEXTS[id].rotation = rotation
end

function module.update_settings(id, preset)
    ensureText(id)

    if type(preset) ~= "table" then error 'invalid preset' end

    TEXTS[id].preset = preset
end

function module.get_entity(id)
    ensureText(id)
    return TEXTS[id].entity
end

function module.set_entity(id, entity)
    ensureText(id)
    TEXTS[id].entity = entity
end

function module.add_blind(id, player)
    ensureText(id)
    TEXTS[id].blind[player.pid] = true
end

function module.remove_blind(id, player)
    ensureText(id)
    TEXTS[id].blind[player.pid] = nil
end

function module.get_in_radius(player_obj)
    local texts = {}

    local radius = player_obj.view_distance
    local x, y, z = player.get_pos(player_obj.pid)
    local pid = player_obj.pid

    for id, text in pairs(TEXTS) do
        if text.blind[pid] then goto continue end

        local tx, tz = text.position[1], text.position[3]
        if text.entity then
            local entity = entities.get(text.entity)
            if entity then
                local pos = entity.transform:get_pos()
                tx, tz = tx + pos[1], tz + pos[3]
            else
                goto continue
            end
        end
        if math.euclidian2D(x, z, tx, tz) <= radius * 16 then
            if chunks_manager.is_loaded(player_obj, math.floor(tx / 16), math.floor(tz / 16)) then
                table.insert(texts, text)
            end
        end
        ::continue::
    end

    return texts
end

return module
