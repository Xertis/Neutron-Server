local events = start_require("server:api/v2/events")
local rpc = require "api/v2/rpc"
local accounts = require "api/v2/accounts"
local bson = require "lib/private/files/bson"
local console = require "api/v2/console"
local sandbox = require "api/v2/sandbox"
local db = require "lib/public/database/api"
local env = start_require("server:api/v2/env")
local interceptors = start_require "api/v2/interceptors"
local entities = require "api/v2/entities"
local protocol = require "api/v2/protocol"
local weather = require "api/v2/weather"
local particles = require "api/v2/particles"
local audio = require "api/v2/audio"
local text3d = require "api/v2/text3d"
local blockwraps = require "api/v2/blockwraps"
local inv_dat = require "api/v2/inv_dat"
local tasks = require "api/v2/tasks"

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
