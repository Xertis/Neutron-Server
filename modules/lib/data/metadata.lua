local module = {
    server = {},
    players = {},
}

local PLAYERS_META = {}
local SERVER_META = {
    accounts = {},
    worlds = {}
}

function module.proxy(meta_type, catalog)
    local set_func = nil
    local get_func = nil
    local meta = {}

    if meta_type == "server" then
        set_func = module.server.set
        get_func = module.server.get

        meta.__index = function(t, key)
            return get_func(catalog, key)
        end

        meta.__newindex = function(t, key, value)
            set_func(catalog, key, value)
        end
    elseif meta_type == "players" then
        set_func = module.players.set
        get_func = module.players.get

        meta.__index = function(t, key)
            return get_func(key)
        end

        meta.__newindex = function(t, key, value)
            set_func(key, value)
        end
    else
        return
    end

    return setmetatable({}, meta)
end

function module.load()
    logger.log("Loading metadata...")

    if file.exists(METADATA_PLAYERS_PATH) then
        local bytes = file.read_bytes(METADATA_PLAYERS_PATH)
        PLAYERS_META = bjson.frombytes(bytes)
    end

    if file.exists(METADATA_SERVER_PATH) then
        local bytes = file.read_bytes(METADATA_SERVER_PATH)
        SERVER_META = bjson.frombytes(bytes)
    end

    logger.log(string.format("PLAYERS_META:\n\n%s\n", json.tostring(PLAYERS_META)), nil, true)
    logger.log(string.format("SERVER_META:\n\n%s\n", json.tostring(SERVER_META)), nil, true)
end

function module.save()
    logger.log("Saving metadata...")

    file.write_bytes(METADATA_PLAYERS_PATH, bjson.tobytes(PLAYERS_META, true))
    file.write_bytes(METADATA_SERVER_PATH, bjson.tobytes(SERVER_META, true))

    logger.log(string.format("PLAYERS_META:\n\n%s\n", json.tostring(PLAYERS_META)), nil, true)
    logger.log(string.format("SERVER_META:\n\n%s\n", json.tostring(SERVER_META)), nil, true)
end

function module.server.get(catalog, key)
    if not SERVER_META[catalog] then SERVER_META[catalog] = {} end

    return SERVER_META[catalog][key]
end

function module.server.set(catalog, key, value)
    SERVER_META[catalog][key] = value
end

function module.players.get(key)
    return PLAYERS_META[key]
end

function module.players.set(key, value)
    PLAYERS_META[key] = value
end

function module.players.get_all()
    return PLAYERS_META
end

return module
