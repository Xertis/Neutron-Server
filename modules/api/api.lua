local events = start_require("server:api/events")
local rpc = require "api/rpc"
local accounts = require "api/accounts"
local bson = require "lib/private/files/bson"
local console = require "api/console"
local sandbox = require "api/sandbox"
local db = require "lib/public/database/api"
local status_controller = start_require "api/status_controller"
local callbacks = start_require "api/callbacks"
local env = start_require("server:api/env")

local api = {
    events = events,
    accounts = accounts,
    rpc = rpc,
    bson = bson,
    console = console,
    sandbox = sandbox,
    db = db,
    env = env
    --callbacks = callbacks
    --status_controller = status_controller
}

return {server = api}