local events = start_require("server:api/events")
local rpc = require "api/rpc"
local accounts = require "api/accounts"
local bson = require "lib/private/files/bson"

local api = {
    events = events,
    accounts = accounts,
    rpc = rpc,
    bson = bson
}

return {server = api}