local module = {
    players = {}
}

local PLAYERS_META = {}

local PATHS = {
    players = "config:player_data.bjson"
}

function module.load()
    if file.exists(PATHS.players) then
        local bytes = file.read_bytes(PATHS.players)
        PLAYERS_META = bjson.frombytes(bytes)
    end
end

function module.save()
    file.write_bytes(PATHS.players, bjson.tobytes(PLAYERS_META, true))
end

function module.players.set(name, values)
    PLAYERS_META[name] = values
end

function module.players.get(name)
    return PLAYERS_META[name]
end

return module
