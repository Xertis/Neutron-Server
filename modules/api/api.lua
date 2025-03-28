local events = start_require("server:api/events")
local rpc = require "api/rpc"
local accounts = require "api/accounts"
local bson = require "lib/private/files/bson"
local console = require "api/console"
local sandbox = require "api/sandbox"
local db = require "lib/public/database/api"

-- Сделай player.suspended

local api = {
    events = events,
    accounts = accounts,
    rpc = rpc,
    bson = bson,
    console = console,
    sandbox = sandbox,
    db = db
}

return {server = api}