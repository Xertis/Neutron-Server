local events = require "api/events"
local rpc = require "api/rpc"

local api = {
    events = events,
    rpc = rpc
}

return {server = api}