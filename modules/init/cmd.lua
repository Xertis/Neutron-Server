local chat = start_require "multiplayer/server/chat/chat"
local tasks = require "api/v2/tasks"

console.add_command(
    "chat message:str",
    "Send message",
    function (args)
        local message = string.format("[#ffff00] [root] %s", args[1])
        chat.echo(message)
    end
)
console.submit = function (command)
    local name, _ = command:match("^(%S+)%s*(.*)$")

    if name == "chat" then
        console.execute(command)
    else
        console.execute("chat '/"..command.."'")
    end
end

logger.log("cmd initialized")