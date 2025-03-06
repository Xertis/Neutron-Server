local protocol = require "lib/public/protocol"
local events = require "api/events"
local bson = require "lib/private/bson"

local module = {}

function module.create_rpc(pack, event_name)
    return function (client, ...)
        local buffer = protocol.create_databuffer()
        local args = bson.encode(buffer, {...})
        events.tell(pack, event_name, client, args.bytes)
    end
end

return module