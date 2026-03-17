local chat = start_require "multiplayer/server/chat/chat"

console.add_command(
    "chat message:str",
    "Send message",
    function(args)
        local message = string.format("[#ffff00] [root] %s", args[1])
        time.post_runnable(function() chat.echo(message) end)
        return "message has been sent"
    end
)

console.add_command(
    "stop",
    "Stops the server",
    function(args)
        time.post_runnable(function() IS_RUNNING = false end)
        return "done"
    end
)

console.submit = function(command)
    local name, _ = command:match("^(%S+)%s*(.*)$")

    if name == "chat" then
        console.execute(command)
    else
        console.execute("chat '/" .. command .. "'")
    end
end

logger.log("cmd initialized")
