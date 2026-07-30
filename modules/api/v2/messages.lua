local protocol = import "net/protocol/protocol"
local compiler = import "net/protocol/compiler"
local events = import "api/v2/events"

local function sorted_keys(tbl)
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys)
    return keys
end

local function compile_schema(schema)
    local entries = {}
    for _, key in ipairs(sorted_keys(schema)) do
        local typ = schema[key]
        if type(typ) == "table" then
            table.insert(entries, { key = key, nested = compile_schema(typ) })
        else
            table.insert(entries, { key = key, type = typ })
        end
    end
    return entries
end

local function collect_types(entries, out)
    out = out or {}
    for _, e in ipairs(entries) do
        if e.nested then
            collect_types(e.nested, out)
        else
            table.insert(out, e.type)
        end
    end
    return out
end

local function flatten(entries, data, out)
    out = out or {}
    data = data or {}
    for _, e in ipairs(entries) do
        if e.nested then
            flatten(e.nested, data[e.key] or {}, out)
        else
            table.insert(out, data[e.key])
        end
    end
    return out
end

local function unflatten(entries, flat_data, idx)
    idx = idx or 1
    local result = {}
    for _, e in ipairs(entries) do
        if e.nested then
            local nested, new_idx = unflatten(e.nested, flat_data, idx)
            result[e.key] = nested
            idx = new_idx
        else
            result[e.key] = flat_data[idx]
            idx = idx + 1
        end
    end
    return result, idx
end

local Message = {}
Message.__index = Message

function Message.new(pack, event, schema)
    local entries = compile_schema(schema)
    local types = collect_types(entries)

    local encoder = compiler.load(compiler.compile_encoder(types))
    local decoder = compiler.load(compiler.compile_decoder(types))

    local self = setmetatable({
        schema = schema,
        pack = pack,
        event = event,
        _entries = entries,
        _encoder = encoder,
        _decoder = decoder,
    }, Message)

    return self
end

function Message:encode(buf, data)
    local flat = flatten(self._entries, data)
    self._encoder(buf, unpack(flat))
    buf:flush()
end

function Message:decode(buf)
    local flat = self._decoder(buf)
    return unflatten(self._entries, flat)
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

function Message:on(handler)
    events.on(self.pack, self.event, function(client, bytes)
        local buf = protocol.create_databuffer(bytes)
        local data = self:decode(buf)
        handler(client, data)
    end)
end

return Message
