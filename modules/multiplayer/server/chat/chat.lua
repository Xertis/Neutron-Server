local protect = require "lib/private/protect"
local protocol = require "lib/public/protocol"
local server_echo = require "multiplayer/server/server_echo"
local states = require "multiplayer/server/chat/chat_states"
local module = {}

local no_logged_commands = {"register", "login"}
local handlers = {}

function module.echo(message)
    logger.log(message)
    server_echo.put_event(function (client)
        local buffer = protocol.create_databuffer()
        buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.ChatMessage, message))
        client.network:send(buffer.bytes)
    end)
end

function module.tell(message, client)
    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.ChatMessage, message))
    client.network:send(buffer.bytes)
end

function module.command(message, client)
    local state = states.get_state(client)

    if message[1] ~= '.' and not state  then
        return false
    end

    if not state then
        message = string.sub(message, 2)
    end

    local args = string.soft_space_split(message)
    local executable = args[1]
    table.remove(args, 1)

    if not client.account.is_logged and not table.has(no_logged_commands, executable) then
        return
    end

    if handlers[executable] and not state then
        handlers[executable].handler(args, client)
    elseif state then
        handlers[state.id].handler(message, state, client)
    else
        module.tell("[#ff0000] Unknow command: " .. executable, client)
    end
end

function module.add_command(schem, handler)
    if handlers[schem[1]] then
        return false
    end

    handlers[schem[1]] = {handler = handler, schem = schem}
    return true
end

function module.set_state_handler(state, handler)
    if handlers[state.id] then
        return false
    end

    handlers[state.id] = {handler = handler}
end

function module.get_handlers()
    local pairs_handlers = {}

    for key, handler in pairs(handlers) do
        if type(key) ~= "number" then
            pairs_handlers[key] = handler
        end
    end
    return pairs_handlers
end

return protect.protect_return(module)