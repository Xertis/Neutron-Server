local module = {
    statuses = {
        WorldPreparing = 0,
        WorldOpen = 1,
        PlayerJoin = 2,
        PlayerLeave = 3,
    }
}

local handlers = {
    on_open = {},
    on_close = {}
}

local active_statuses = {}

function module.has_status(status)
    return active_statuses[status] ~= nil
end

function module.get_statuses()
    return table.deep_copy(active_statuses)
end

function module.on_open(status, handler)
    local status_table = table.set_default(handlers.on_open, status, {})
    table.insert(status_table, handler)
end

function module.on_close(status, handler)
    local status_table = table.set_default(handlers.on_close, status, {})
    table.insert(status_table, handler)
end

function module.__emit_open__(status, ...)
    active_statuses[status] = true
    local status_table = table.set_default(handlers.on_open, status, {})
    for _, handler in ipairs(status_table) do
        handler(...)
    end
end

function module.__emit_close__(status, ...)
    local status_table = table.set_default(handlers.on_close, status, {})
    for _, handler in ipairs(status_table) do
        handler(...)
    end
    active_statuses[status] = nil
end

return module