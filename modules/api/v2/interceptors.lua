local protocol = require "multiplayer/protocol-kernel/protocol"

local server_matches = start_require("multiplayer/server/server_matches")
local switcher = server_matches.client_online_handler

local fsm_interceptors = {}
local fsm_generic_interceptors = {}

local receive_interceptors = {}
local generic_receive_interceptors = {}

local send_interceptors = {}
local generic_send_interceptors = {}

local module = {
    packets = {
        ServerMsg = protocol.ServerMsg,
        ClientMsg = protocol.ClientMsg
    },
    receive = {},
    send = {}
}

function module.send.add_interceptor(packet_type, interceptor)
    if type(interceptor) ~= "function" then
        return error("Incorrect argument type")
    end

    if not IS_RUNNING then return end

    local packet_interceptors = table.set_default(send_interceptors, packet_type, {})
    table.insert(packet_interceptors, interceptor)
end

function module.send.add_generic_interceptor(interceptor)
    if type(interceptor) ~= "function" then
        return error("Incorrect argument type")
    end

    if not IS_RUNNING then return end

    table.insert(generic_send_interceptors, interceptor)
end

function module.receive.add_interceptor(packet_type, interceptor)
    if type(interceptor) ~= "function" then
        return error("Incorrect argument type")
    end

    if not IS_RUNNING then return end

    local packet_interceptors = table.set_default(receive_interceptors, packet_type, {})
    table.insert(packet_interceptors, interceptor)
end

function module.receive.add_generic_interceptor(interceptor)
    if type(interceptor) ~= "function" then
        return error("Incorrect argument type")
    end

    if not IS_RUNNING then return end

    table.insert(generic_receive_interceptors, interceptor)
end

function module.send.__process(client, packet_type, packet)
    local original = table.deep_copy(packet)
    for _, interceptor in ipairs(send_interceptors[packet_type] or {}) do
        if not interceptor(client, table.deep_copy(original), packet) then
            return false
        end
    end

    for _, interceptor in ipairs(generic_send_interceptors) do
        if not interceptor(client, table.deep_copy(original), packet) then
            return false
        end
    end

    return true
end

function module.receive.__process(packet, client)
    local packet_type = packet.packet_type
    local original = table.deep_copy(packet)
    for _, interceptor in ipairs(receive_interceptors[packet_type] or {}) do
        if not interceptor(client, table.deep_copy(original), packet) then
            return false
        end
    end

    for _, interceptor in ipairs(generic_receive_interceptors) do
        if not interceptor(client, table.deep_copy(original), packet) then
            return false
        end
    end

    return true
end

switcher:add_middleware(module.receive.__process)

return module