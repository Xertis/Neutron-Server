local events = import("server:api/v1/events")
local rpc = import "api/v1/rpc"
local accounts = import "api/v1/accounts"
local bson = import "lib/data/bson"
local console = import "api/v1/console"
local sandbox = import "api/v1/sandbox"
local db = import "lib/db/api"
local env = import("server:api/v1/env")
local middlewares = import "api/v1/middlewares"
local entities = import "api/v1/entities"
local protocol = import "api/v1/protocol"
local weather = import "api/v1/weather"
local particles = import "api/v1/particles"
local audio = import "api/v1/audio"
local text3d = import "api/v1/text3d"
local blockwraps = import "api/v1/blockwraps"
local inv_dat = import "api/v1/inv_dat"
local tasks = import "api/v1/tasks"

local api = {
    events = events,
    accounts = accounts,
    rpc = rpc,
    bson = bson,
    console = console,
    sandbox = sandbox,
    db = db,
    env = env,
    middlewares = middlewares,
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
