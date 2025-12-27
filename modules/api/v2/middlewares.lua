local protocol = require "multiplayer/protocol-kernel/protocol"

local server_matches = start_require("multiplayer/server/server_matches")
local switcher = server_matches.client_online_handler

local fsm_middlewares = {}
local fsm_generic_middlewares = {}

local receive_middlewares = {}
local generic_receive_middlewares

local send_middlewares = {}
local generic_send_middlewares = {}

local module = {
    packets = {
        ServerMsg = protocol.ServerMsg,
        ClientMsg = protocol.ClientMsg
    },
    receive = {},
    send = {}
}

function module.send.add_middleware(packet_type, middleware)
    if type(middleware) ~= "function" then
        return error("Incorrect argument type")
    end

    send_middlewares[packet_type] = table.insert(table.set_default(send_middlewares, packet_type, {}), middleware)
end

function module.send.add_generic_middleware(packet_type, middleware)
    if type(middleware) ~= "function" then
        return error("Incorrect argument type")
    end

    table.insert(generic_send_middlewares, middleware)
end

function module.receive.add_middleware(packet_type, middleware)
    if type(middleware) ~= "function" then
        return error("Incorrect argument type")
    end

    receive_middlewares[packet_type] = table.insert(table.set_default(receive_middlewares, packet_type, {}), middleware)
end

function module.receive.add_generic_middleware(packet_type, middleware)
    if type(middleware) ~= "function" then
        return error("Incorrect argument type")
    end

    table.insert(generic_receive_middlewares, middleware)
end

function module.send.__process(client, packet_type, packet)
    local original = table.deep_copy(packet)
    for _, middleware in ipairs(send_middlewares[packet_type] or {}) do
        if not middleware(client, table.deep_copy(original), packet) then
            return false
        end
    end

    for _, middleware in ipairs(generic_send_middlewares) do
        if not middleware(client, table.deep_copy(original), packet) then
            return false
        end
    end

    return true
end

function module.receive.__process(packet, client)
    local packet_type = packet.packet_type
    local original = table.deep_copy(packet)
    for _, middleware in ipairs(receive_middlewares[packet_type] or {}) do
        if not middleware(client, table.deep_copy(original), packet) then
            return false
        end
    end

    for _, middleware in ipairs(generic_receive_middlewares) do
        if not middleware(client, table.deep_copy(original), packet) then
            return false
        end
    end

    return true
end

function module.receive.__fsm_emit(packet_type, packet, client)
    local middlewares = {}
    local original_packet = table.deep_copy(packet)
    table.merge(middlewares, fsm_middlewares[packet_type] or {})
    table.merge(middlewares, fsm_generic_middlewares)

    for _, middleware in ipairs(middlewares) do
        local status = middleware(client, table.deep_copy(original_packet), packet)

        if not status then
            return false
        end
    end

    return true
end

switcher:add_middleware(module.receive.__process)

return module