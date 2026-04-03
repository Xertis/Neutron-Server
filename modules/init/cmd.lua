local chat = import "core/sandbox/chat/chat"
local accounts = import "api/v2/accounts"
local sandbox = import "api/v2/sandbox"

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
        local reason = "Server is shutting down"
        local players = sandbox.players.get_all()
        for _, player in pairs(players) do
            local account = accounts.by_identity.get_account(player.identity)
            if account then
                accounts.kick(account, reason)
            end
        end
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
