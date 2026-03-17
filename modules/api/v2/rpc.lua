local events = start_require("server:api/v2/events")
local bson = require "lib/data/bson"

local module = {
    emitter = {},
    handler = {}
}

function module.emitter.create_tell(pack, event)
    return function(client, ...)
        local bytes = compression.encode(bson.serialize({ ... }))
        events.tell(pack, event, client, bytes)
    end
end

function module.emitter.create_echo(pack, event)
    return function(...)
        local bytes = compression.encode(bson.serialize({ ... }))
        events.echo(pack, event, bytes)
    end
end

function module.handler.on(pack, event, handler)
    events.on(pack, event, function(client, bytes)
        local data = bson.deserialize(compression.decode(bytes))

        handler(client, unpack(data))
    end)
end

return module
