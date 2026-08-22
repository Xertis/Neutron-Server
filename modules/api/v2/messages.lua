local protocol = import "net/protocol/protocol"
local compiler = import "net/protocol/compiler"
local events = import "api/v2/events"

local function schema_to_fields(schema, prefix, out)
    out = out or {}
    for key, typ in pairs(schema) do
        local full_key = prefix and (prefix .. "." .. key) or key
        if type(typ) == "table" then
            schema_to_fields(typ, full_key, out)
        else
            out[full_key] = typ
        end
    end
    return out
end

local Message = {}
Message.__index = Message

function Message.new(pack, event, schema)
    local fields = schema_to_fields(schema)

    local encoder = compiler.load(compiler.compile_encoder(fields))
    local decoder = compiler.load(compiler.compile_decoder(fields))

    local self = setmetatable({
        schema = schema,
        pack = pack,
        event = event,
        _encoder = encoder,
        _decoder = decoder,
    }, Message)

    return self
end

function Message:encode(buf, data)
    self._encoder(buf, data or {})
    buf:flush()
end

function Message:decode(buf)
    return self._decoder(buf)
end

function Message:tell(client, data)
    local buf = protocol.create_databuffer()
    self:encode(buf, data)
    events.tell(self.pack, self.event, client, buf.bytes)
end

function Message:echo(data)
    local buf = protocol.create_databuffer()
    self:encode(buf, data)
    events.echo(self.pack, self.event, buf.bytes)
end

function Message:selective_echo(data, selector)
    local buf = protocol.create_databuffer()
    self:encode(buf, data)
    events.selective_echo(self.pack, self.event, buf.bytes, selector)
end

function Message:on(handler)
    events.on(self.pack, self.event, function(client, bytes)
        local buf = protocol.create_databuffer(bytes)
        local data = self:decode(buf)
        handler(client, data)
    end)
end

return Message
