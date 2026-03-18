local events = import("server:api/v2/events")
local rpc = import "api/v2/rpc"
local accounts = import "api/v2/accounts"
local bson = import "lib/data/bson"
local console = import "api/v2/console"
local sandbox = import "api/v2/sandbox"
local db = import "lib/db/api"
local env = import("server:api/v2/env")
local interceptors = import "api/v2/interceptors"
local entities = import "api/v2/entities"
local protocol = import "api/v2/protocol"
local weather = import "api/v2/weather"
local particles = import "api/v2/particles"
local audio = import "api/v2/audio"
local text3d = import "api/v2/text3d"
local blockwraps = import "api/v2/blockwraps"
local inv_dat = import "api/v2/inv_dat"
local tasks = import "api/v2/tasks"

local api = {
    events = events,
    accounts = accounts,
    rpc = rpc,
    bson = bson,
    console = console,
    sandbox = sandbox,
    db = db,
    env = env,
    interceptors = interceptors,
    protocol = protocol,
    entities = entities,
    weather = weather,
    particles = particles,
    audio = audio,
    text3d = text3d,
    blockwraps = blockwraps,
    inventory_data = inv_dat,
    tasks = tasks,
    constants = {
        config = CONFIG,
        render_distance = RENDER_DISTANCE,
        tps = TPS
    }

}

return { server = api }
