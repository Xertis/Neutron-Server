local events = start_require("server:api/events")
local rpc = require "api/rpc"
local accounts = require "api/accounts"
local bson = require "lib/private/files/bson"
local console = require "api/console"
local sandbox = require "api/sandbox"
local db = require "lib/public/database/api"
local env = start_require("server:api/env")
local middlewares = require "api/middlewares"
local entities = require "api/entities"
local protocol = require "api/protocol"
local weather = require "api/weather"
local particles = require "api/particles"
local audio = require "api/audio"
local text3d = require "api/text3d"
local blockwraps = require "api/blockwraps"
local inv_dat = require "api/inv_dat"

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
        render_distance = RENDER_DISTANCE
    }

}

return {server = api}