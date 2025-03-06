local protocol = require "lib/public/protocol"
local events = require "api/events"
local bson = require "lib/private/files/bson"

local module = {}

function module.create(pack, event)
    return function (client, ...)
        local buffer = protocol.create_databuffer()
        local args = bson.encode(buffer, {...})
        events.tell(pack, event, client, args.bytes)
    end
end

return module