local protect = require "lib/private/protect"
if protect.protect_require() then return end

local bson = require "lib/private/files/bson"

local module = {
    server = {},
    players = {}
}

local PATHS = {
    players = "world:players_data.dat",
    server = "config:server.dat"
}

if hud then
    PATHS.server = "world:server.dat"
end

local PLAYERS_META = {}
local SERVER_META = {
    accounts = {}
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

    if file.exists(PATHS.players) then
        local bytes = file.read_bytes(PATHS.players)
        PLAYERS_META = bson.deserialize(bytes)
    end

    if file.exists(PATHS.server) then
        local bytes = file.read_bytes(PATHS.server)
        SERVER_META = bson.deserialize(bytes)
    end

    logger.log(string.format("PLAYERS_META:\n\n%s\n", json.tostring(PLAYERS_META)), nil, true)
    logger.log(string.format("SERVER_META:\n\n%s\n", json.tostring(SERVER_META)), nil, true)
end

function module.save()
    logger.log("Saving metadata...")

    file.write_bytes(PATHS.players, bson.serialize(PLAYERS_META))
    file.write_bytes(PATHS.server, bson.serialize(SERVER_META))

    logger.log(string.format("PLAYERS_META:\n\n%s\n", json.tostring(PLAYERS_META)), nil, true)
    logger.log(string.format("SERVER_META:\n\n%s\n", json.tostring(SERVER_META)), nil, true)
end

function module.server.get(catalog, key)
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
