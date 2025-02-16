local protect = require "lib/private/protect"
local protocol = require "lib/public/protocol"
local server_echo = require "multiplayer/server/server_echo"
local sandbox = require "lib/private/sandbox/sandbox"
local switcher = require "lib/public/common/switcher"
local module = {}

local colors = {
    red = "[#ff0000]",
    white = ""
}

local commands = switcher.new(function ( ... )
    local values = {...}
    local client = values[3]
    local command = values[1]

    local message = "Unknow command"
    module.tell(string.format("%s %s: %s", colors.red, message, command), client)
end)

commands:add_case("list", function ( ... )
    local values = {...}
    local client = values[3]
    local players = table.keys(sandbox.get_players())

    local message = "Online players"
    module.tell(string.format("%s %s: %s", colors.white, message, table.tostring(players)), client)

end)

commands:add_case("help", function ( ... )
    local values = {...}
    local client = values[3]
    local message = ''
    local messages= {
        "----- Help (.help) -----",
        ".help - Shows a list of available commands.",
        ".list - Shows a list of online players."
    }

    for _, m in ipairs(messages) do
        message = message .. m .. '\n'
    end

    module.tell(string.format("%s %s", colors.white, message), client)

end)

function module.echo(message)
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

    commands:switch(executable, executable, args, client)
end

return protect.protect_return(module)