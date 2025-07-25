local events = start_require("server:api/v1/events")
local rpc = require "api/v1/rpc"
local accounts = require "api/v1/accounts"
local bson = require "lib/private/files/bson"
local console = require "api/v1/console"
local sandbox = require "api/v1/sandbox"
local db = require "lib/public/database/api"
local env = start_require("server:api/v1/env")
local middlewares = start_require "api/v1/middlewares"
local entities = require "api/v1/entities"
local protocol = require "api/v1/protocol"
local weather = require "api/v1/weather"
local particles = require "api/v1/particles"
local audio = require "api/v1/audio"
local text3d = require "api/v1/text3d"
local blockwraps = require "api/v1/blockwraps"
local inv_dat = require "api/v1/inv_dat"

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
    constants = {
        config = CONFIG,
        render_distance = RENDER_DISTANCE,
        tps = TPS
    }

}

return { server = api }
