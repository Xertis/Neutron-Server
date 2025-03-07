local events = require "api/events"
local rpc = require "api/rpc"
local accounts = require "api/accounts"

local api = {
    events = events,
    accounts = accounts
}

return {server = api}