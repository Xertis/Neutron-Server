local messages = import "api/v2/messages"
local server_echo = import "lib/flow/server_echo"

local Replication = {}

local REPLICATORS = {}

local function has_null(schema)
    for key, typ in pairs(schema) do
        if type(typ) == "string" then
            if typ:find("NullAble<") then return true end
        else
            if has_null(typ) then
                return true
            end
        end
    end
    return false
end

local function nullabling(schema)
    local nullable = {}
    for key, typ in pairs(schema) do
        if type(typ) == "string" then
            nullable[key] = "NullAble<" .. typ .. ">"
        else
            nullable[key] = nullabling(typ)
        end
    end
    return nullable
end

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

local function diff(compiled, new, old)
    local result = nil
    for i = 1, #compiled do
        local f = compiled[i]
        local k = f.key

        if f.nested then
            local sub = diff(f.nested, new[k], old[k])
            if sub then
                result = result or {}
                result[k] = sub
            end
        else
            local nv = new[k]
            if nv ~= old[k] then
                result = result or {}
                result[k] = nv
            end
        end
    end
    return result
end

local function apply_diff(compiled, target, patch)
    if not patch then return target end
    for i = 1, #compiled do
        local f = compiled[i]
        local k = f.key
        local p = patch[k]

        if p ~= nil then
            if f.nested then
                apply_diff(f.nested, target[k], p)
            else
                target[k] = p
            end
        end
    end
    return target
end

local Replicator = {}
Replicator.__index = Replicator

function Replication.new(pack, event, schema)
    if has_null(schema) then
        error("Replication схема не может иметь NullAble тип")
    end

    schema = nullabling(schema)

    local compiled_schema = compile_schema(schema)
    schema._rep_id = "var"

    local message = messages.new(pack, event, schema)
    local replicator_id = #REPLICATORS + 1

    local self = setmetatable({
        _compiled_schema = compiled_schema,
        _message = message,
        _sources = {},
        _id = replicator_id
    }, Replicator)

    REPLICATORS[replicator_id] = self

    return self
end

function Replicator:create_public_replica(id, initial_value, need_send)
    self._sources[id] = {
        _is_echo = true,
        _need_send = need_send,
        _old_data = table.deep_copy(initial_value)
    }
    table.merge(self._sources[id], table.deep_copy(initial_value))
    return self._sources[id]
end

function Replicator:create_private_replica(id, initial_value, client)
    self._sources[id] = {
        _client = client,
        _old_data = table.deep_copy(initial_value)
    }
    table.merge(self._sources[id], table.deep_copy(initial_value))
    return self._sources[id]
end

function Replicator:remove_replica(id)
    if self._sources[id] then
        self._sources[id] = nil
    end
end

function Replication.__process()
    for _, replicator in ipairs(REPLICATORS) do
        local schema = replicator._compiled_schema
        local message = replicator._message

        for id, source in pairs(replicator._sources) do
            local dirty = diff(schema, source, source._old_data)
            local need_send = source._need_send

            if dirty then
                dirty._rep_id = id
                if source._is_echo then
                    if not need_send then
                        message:echo(dirty)
                    else
                        server_echo.put_event(function(client)
                            if need_send(client, dirty) then
                                message:tell(client, dirty)
                            end
                        end)
                    end
                else
                    message:tell(source._client, dirty)
                end
                source._old_data = apply_diff(schema, source._old_data, dirty)
            end
        end
    end
end

return Replication
