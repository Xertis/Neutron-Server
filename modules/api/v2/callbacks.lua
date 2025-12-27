local module = {
    events = {
        OnPreparing = "on_preparing",
        OnOpen = "on_open",
        OnJoin = "on_join",
        OnLeave = "on_leave"
    }
}
local handlers = {
    on_preparing = {},
    on_open = {},
    on_join = {},
    on_leave = {}
}

function module.add_callback(event, handler)
    if not handlers[event] then
        error(string.format('The event "%s" is not available', event))
    end

    table.insert(handlers[event], handler)
end

function module.__emit__(event, ...)
    for _, handler in ipairs(handlers[event]) do
        handler(...)
    end
end