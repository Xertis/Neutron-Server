local protect = require "lib/private/protect"
if protect.protect_require() then return end

local module = {
    players = {},
    accounts = {},
    world = {}
}

local PATHS = {
    world = "world:world_data.bjson",
    players = "world:players_data.bjson",
    server = "config:server.dat"
}

local SERVER_META_PATTERN = { "accounts" }

local PLAYERS_META = {}
local WORLD_META = {}
local SERVER_META = { accounts = {} }

function module.load()
    logger.log("Loading metadata...")

    if file.exists(PATHS.players) then
        local bytes = file.read_bytes(PATHS.players)
        PLAYERS_META = bjson.frombytes(bytes)
    end

    if file.exists(PATHS.world) then
        local bytes = file.read_bytes(PATHS.world)
        WORLD_META = bjson.frombytes(bytes)
    end

    if file.exists(PATHS.server) then
        local bytes = file.read_bytes(PATHS.server)
        SERVER_META = table.to_dict(bjson.archive_frombytes(bytes), SERVER_META_PATTERN)
    end

    logger.log(string.format("PLAYERS_META:\n\n%s\n", json.tostring(PLAYERS_META)), nil, true)
    logger.log(string.format("SERVER_META:\n\n%s\n", json.tostring(SERVER_META)), nil, true)
    logger.log(string.format("WORLD_META:\n\n%s\n", json.tostring(WORLD_META)), nil, true)
end

function module.save()
    logger.log("Saving metadata...")

    file.write_bytes(PATHS.players, bjson.tobytes(PLAYERS_META, true))
    file.write_bytes(PATHS.world, bjson.tobytes(WORLD_META, true))
    file.write_bytes(PATHS.server, bjson.archive_tobytes(table.to_arr(SERVER_META, SERVER_META_PATTERN), true))

    logger.log(string.format("PLAYERS_META:\n\n%s\n", json.tostring(PLAYERS_META)), nil, true)
    logger.log(string.format("SERVER_META:\n\n%s\n", json.tostring(SERVER_META)), nil, true)
    logger.log(string.format("WORLD_META:\n\n%s\n", json.tostring(WORLD_META)), nil, true)
end

-- Мир

function module.world.set(name, values)
    WORLD_META[name] = values
end

function module.world.get(name)
    return WORLD_META[name]
end

function module.world.get_all()
    return table.deep_copy(WORLD_META)
end

-- Игроки

function module.players.set(name, values)
    PLAYERS_META[name] = values
end

function module.players.get(name)
    return PLAYERS_META[name]
end

function module.players.get_all()
    return table.deep_copy(PLAYERS_META)
end

-- Аккаунты

function module.accounts.set(name, values)
    SERVER_META.accounts[name] = values
end

function module.accounts.get(name)
    return SERVER_META.accounts[name]
end

return module
