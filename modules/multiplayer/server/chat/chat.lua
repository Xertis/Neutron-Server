local protect = require "lib/private/protect"
local protocol = require "lib/public/protocol"
local server_echo = require "multiplayer/server/server_echo"
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
    if message[1] ~= '.' then
        return
    end

    message = string.sub(message, 2)
    local args = string.split(message, " ")
    local executable = args[1]
    table.remove(args, 1)

    if not client.account.is_logged and not table.has(no_logged_commands, executable) then
        return
    end

    if handlers[executable] then
        handlers[executable].handler(args, client)
    else
        module.tell("[#ff0000] Unknow command: " .. executable, client)
    end
end

function module.add_command(schem, handler)
    handlers[schem[1]] = {handler = handler, schem = schem}
end

function module.get_handlers()
    return handlers
end

return protect.protect_return(module)