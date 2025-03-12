local protocol = require "lib/public/protocol"
local sandbox = require "lib/private/sandbox/sandbox"
local switcher = require "lib/public/common/switcher"
local account_manager = require "lib/private/accounts/account_manager"
local protect = require "lib/private/protect"
local lib = require "lib/private/min"

local colors = {
    red = "[#ff0000]",
    yellow = "[#ffff00]",
    white = ""
}

local chat = {chat = {}}

local commands = switcher.new(function ( ... )
    local values = {...}
    local client = values[3]
    local command = values[1]

    local message = "Unknow command"
    chat.chat.tell(string.format("%s %s: %s", colors.red, message, command), client)
end)

commands:add_case("list", function ( ... )
    local values = {...}
    local client = values[3]
    local players = table.keys(sandbox.get_players())

    local message = "Online players"
    chat.chat.tell(string.format("%s %s: %s", colors.white, message, table.tostring(players)), client)

end)

commands:add_case("help", function ( ... )
    local values = {...}
    local client = values[3]
    local message = ''
    local messages= {
        "----- Help (.help) -----",
        ".help - Shows a list of available commands.",
        ".list - Shows a list of online players.",
        ".kick <nickname> [reason] - Kicks the user",
        ".role [nickname] - Returns the role of the user",
        ".role_set <nickname> <role> - Changes the role of the selected player",
        ".time_set <time> - Sets the game time"
    }

    for _, m in ipairs(messages) do
        message = message .. m .. '\n'
    end

    chat.chat.tell(string.format("%s %s", colors.white, message), client)
end)

commands:add_case("register", function ( ... )
    local values = {...}
    local client = values[3]
    local account = client.account
    local passwords = values[2]

    if account.is_logged then
        chat.chat.tell(string.format("%s You are already logged in.", colors.yellow), client)
        return
    elseif account.password ~= nil then
        chat.chat.tell(string.format("%s Please log in using the command .login <password> to access your account.", colors.yellow), client)
        return
    end

    if passwords[1] ~= passwords[2] then
        chat.chat.tell(string.format("%s The passwords you entered do not match. Please try again using the command .register", colors.red), client)
        return
    end

    local status = account:set_password(passwords[1])

    if status == CODES.accounts.PasswordUnvalidated then
        chat.chat.tell(string.format("%s Your password does not meet the requirements, create a new one.", colors.red), client)
        return
    end

    account.is_logged = true
    chat.chat.tell(string.format("%s You have successfully registered!", colors.yellow), client)
end)

commands:add_case("login", function ( ... )
    local values = {...}
    local client = values[3]
    local account = client.account
    local password = values[2][1]

    if account.is_logged then
        chat.chat.tell(string.format("%s You are already logged in.", colors.yellow), client)
        return
    elseif account.password == nil then
        chat.chat.tell(string.format("%s Please register using the command .register <password> <confirm password> to secure your account.", colors.yellow), client)
        return
    end

    local status = account:check_password(password)
    if status == CODES.accounts.WrongPassword then
        chat.chat.tell(string.format("%s Incorrect password. Please try again using the command .login <password>.", colors.red), client)
        return
    end

    chat.chat.tell(string.format("%s You have successfully logged in!", colors.yellow), client)
end)

commands:add_case("kick", function ( ... )
    local values = {...}
    local client = values[3]
    local account = client.account
    local kick_username = values[2][1] or ''
    local reason = values[2][2] or "No reason"
    local kick_account = account_manager.by_username.get_account(kick_username)

    local client_role = account_manager.get_role(account)
    local kick_role = account_manager.get_role(kick_account)

    if not kick_role or not sandbox.by_username.is_online(kick_username) then
        chat.chat.tell(string.format('%s The player "%s" is currently offline!', colors.red, kick_username), client)
        return
    elseif kick_username == client.player.username then
        chat.chat.tell(string.format("%s You cannot kick yourself!", colors.red), client)
        return
    elseif not client_role.server_rules.kick then
        chat.chat.tell(string.format("%s You do not have sufficient permissions to perform this action!", colors.red), client)
        return
    elseif not lib.roles.is_higher(client_role, kick_role) then
        chat.chat.tell(string.format("%s You cannot interact with this player because their role has a higher or equal priority!", colors.red), client)
        return
    end

    local kick_client = account_manager.get_client(kick_account)

    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.Disconnect, reason))
    kick_client.network:send(buffer.bytes)

    chat.chat.echo(string.format("%s [%s] Player **%s** has been kicked with reason: %s", colors.red, account.username, kick_username, reason))
    kick_client.active = false
end)

commands:add_case("role", function ( ... )
    local values = {...}
    local client = values[3]
    local username = values[2][1] or client.account.username
    local account = account_manager.by_username.get_account(username)

    if not account or not sandbox.by_username.is_online(username) then
        chat.chat.tell(string.format('%s The player "%s" is currently offline!', colors.red, username), client)
        return
    end

    chat.chat.tell(string.format('%s The role of the player "%s" is: %s', colors.yellow, username, account.role), client)
end)

commands:add_case("role_set", function ( ... )
    local values = {...}
    local client = values[3]
    local account = client.account
    local subject_username = values[2][1] or ''
    local role = values[2][2] or ''
    local subject_account = account_manager.by_username.get_account(subject_username)

    local client_role = account_manager.get_role(account)
    local subject_role = account_manager.get_role(subject_account)

    if not subject_role or not sandbox.by_username.is_online(subject_username) then
        chat.chat.tell(string.format('%s The player "%s" is currently offline!', colors.red, subject_username), client)
        return
    elseif subject_username == client.player.username then
        chat.chat.tell(string.format("%s You cannot change your own role!", colors.red), client)
        return
    elseif not client_role.server_rules.role_management then
        chat.chat.tell(string.format("%s You do not have sufficient permissions to perform this action!", colors.red), client)
        return
    elseif not lib.roles.is_higher(client_role, subject_role) then
        chat.chat.tell(string.format("%s You cannot interact with this player because their role has a higher or equal priority!", colors.red), client)
        return
    elseif not lib.roles.exists(role) then
        chat.chat.tell(string.format("%s Role: %s does not exist!", role, colors.red), client)
        return
    elseif not lib.roles.is_higher(client_role, CONFIG.roles[role]) then
        chat.chat.tell(string.format("%s You can't give a role to a player that's higher than yours!", colors.red), client)
        return
    end

    subject_account.role = role

    chat.chat.echo(string.format("%s [%s] Player **%s** has been kicked with reason: %s", colors.red, account.username, kick_username, reason))
end)

commands:add_case("time_set", function ( ... )
    local values = {...}
    local client = values[3]
    local time = values[2][1]
    local account = client.account

    local role = account_manager.get_role(account)
    if not role.server_rules.time_management then
        chat.chat.tell(string.format("%s You do not have sufficient permissions to perform this action!", colors.red), client)
        return
    elseif not time then
        chat.chat.tell(string.format('%s Incorrect time entered! Please enter a number between 0 and 1', colors.red), client)
        return
    end

    local status = sandbox.set_day_time(time)
    if status then
        chat.chat.echo(string.format('%s [%s] Time has been changed to: %s', colors.yellow, account.username, time))
    else
        chat.chat.tell(string.format("%s Incorrect time entered! Please enter a number between 0 and 1", colors.red), client)
    end
end)

-- commands:add_case("png", function ( ... )
--     local img = require "libpng:image"
--     img = img:new(2000, 2000)

--     local n1 = math.floor(-1000 / 16)
--     local n2 = math.floor(1000 / 16)

--     local x1, z1 = n1, n1
--     local x2, z2 = n2, n2

--     for x=x1, x2 do
--         for z=z1, z2 do
--             local v = world.get_chunk_data(x, z)
--             if v then
--                 img:set(x+62, z+62, 255, 255, 255, 255)
--             else
--                 img:set(x+62, z+62, 0, 0, 0, 255)
--             end
--         end
--     end

--     local x, y, z = player.get_pos(1)
--     x, z = math.floor(x / 16) + 62, math.floor(z / 16) + 62
--     img:set(x, z, 255, 0, 0, 255)

--     x, y, z = player.get_pos(0)
--     x, z = math.floor(x / 16) + 62, math.floor(z / 16) + 62
--     img:set(x, z, 255, 0, 0, 255)

--     img:to_png("export:rferg.png")
-- end)

return protect.protect_return({commands, chat})