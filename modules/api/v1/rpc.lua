local events = start_require("server:api/v1/events")
local bson = require "lib/private/files/bson"
local db = require "lib/public/bit_buffer"

local module = {
    emitter = {},
    handler = {}
}

function module.emitter.create_tell(pack, event)
    return function (client, ...)
        local buffer = db:new()
        bson.encode(buffer, {...})
        events.tell(pack, event, client, buffer.bytes)
    end
end

function module.emitter.create_echo(pack, event)
    return function (...)
        local buffer = db:new()
        bson.encode(buffer, {...})
        events.echo(pack, event, buffer.bytes)
    end
end

return module