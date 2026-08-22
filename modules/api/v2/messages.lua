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

local function compile_encoder_decoder(schema)
    local fields = schema_to_fields(schema)

    local encoder = compiler.load(compiler.compile_encoder(fields))
    local decoder = compiler.load(compiler.compile_decoder(fields))

    return encoder, decoder
end

local Message = {}
Message.__index = Message

function Message.new(pack, event, schema)
    local encoder, decoder
    if schema then
        encoder, decoder = compile_encoder_decoder(schema)
    else
        encoder, decoder = function() end, function() end
    end

    local self = setmetatable({
        schema = schema,
        pack = pack,
        event = event,
        is_requested = false,
        self_side = vc.is_headless() and "server" or "client",
        goal_side = nil,
        encoder = encoder,
        decoder = decoder,
    }, Message)

    return self
end

function Message:__call(properties)
    if properties.schema and not self.encoder then
        local encoder, decoder = compile_encoder_decoder(properties.schema)

        self.encoder = encoder
        self.decoder = decoder
    elseif properties.request and not self.encoder then
        self.is_requested = true

        local req_encoder, req_decoder = compile_encoder_decoder(properties.request)
        local res_encoder, res_decoder = compile_encoder_decoder(properties.response)

        self.request_encoder = req_encoder
        self.request_decoder = req_decoder

        self.response_encoder = res_encoder
        self.response_decoder = res_decoder
    else
        error("Invalid 'properties' or an attempt was made to modify 'properties'")
    end

    return self
end

local function select_side(self, side)
    if self.goal_side then
        error("You cannot change the side of a message a second time")
    end

    if self.encoder then
        error("You cannot select a side once 'properties' has already been declared")
    end

    self.goal_side = side

    if self.request_encoder then
        if self.goal_side ~= self.self_side then
            self.encoder = self.request_encoder
            self.decoder = self.response_decoder
        else
            self.encoder = self.response_encoder
            self.decoder = self.request_decoder
        end
    end
end

function Message:client(properties)
    if properties then self(properties) end
    select_side(self, "client")

    return self
end

function Message:server(properties)
    if properties then self(properties) end
    select_side(self, "server")

    return self
end

function Message:encode(buf, data)
    self.encoder(buf, data or {})
    buf:flush()
end

function Message:decode(buf)
    return self.decoder(buf)
end

function Message:tell(client, data)
    if self.goal_side and self.goal_side ~= self.self_side then
        return
    end

    local buf = protocol.create_databuffer()
    self:encode(buf, data)
    events.tell(self.pack, self.event, client, buf.bytes)
end

function Message:echo(data)
    if self.goal_side and self.goal_side ~= self.self_side then
        return
    end

    local buf = protocol.create_databuffer()
    self:encode(buf, data)
    events.echo(self.pack, self.event, buf.bytes)
end

function Message:selective_echo(data, selector)
    if self.goal_side and self.goal_side ~= self.self_side then
        return
    end

    local buf = protocol.create_databuffer()
    self:encode(buf, data)
    events.selective_echo(self.pack, self.event, buf.bytes, selector)
end

function Message:on(handler)
    local wrap
    if self.goal_side and self.goal_side ~= self.self_side then
        wrap = function(client, bytes)
            local buf = protocol.create_databuffer(bytes)
            local data = self:decode(buf)

            local response = handler(client, data)
            self:tell(client, response)
        end
    else
        wrap = function(client, bytes)
            local buf = protocol.create_databuffer(bytes)
            local data = self:decode(buf)
            handler(client, data)
        end
    end
    events.on(self.pack, self.event, wrap)
end

return Message
