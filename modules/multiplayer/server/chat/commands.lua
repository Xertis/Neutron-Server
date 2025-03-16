local protocol = require "lib/public/protocol"
local sandbox = require "lib/private/sandbox/sandbox"
local account_manager = require "lib/private/accounts/account_manager"
local lib = require "lib/private/min"
local console = require "api/console"


console.set_command("list: -> Shows a list of online players", {}, function (args, client)
    local players = table.keys(sandbox.get_players())

    local message = "Online players"
    console.tell(string.format("%s %s: %s", console.colors.white, message, table.tostring(players)), client)

end)

console.set_command("register: password=<string>, rpassword=<string> -> Registration", {}, function (args, client)
    local account = client.account
    local passwords = {args.password, args.rpassword}

    if account.is_logged then
        console.tell(string.format("%s You are already logged in.", console.colors.yellow), client)
        return
    elseif account.password ~= nil then
        console.tell(string.format("%s Please log in using the command .login <password> to access your account.", console.colors.yellow), client)
        return
    end

    if passwords[1] ~= passwords[2] then
        console.tell(string.format("%s The passwords you entered do not match. Please try again using the command .register", console.colors.red), client)
        return
    end

    local status = account:set_password(passwords[1])

    if status == CODES.accounts.PasswordUnvalidated then
        console.tell(string.format("%s Your password does not meet the requirements, create a new one.", console.colors.red), client)
        return
    end

    account.is_logged = true
    console.tell(string.format("%s You have successfully registered!", console.colors.yellow), client)
end)

console.set_command("login: password=<string> -> Logging", {}, function (args, client)
    local account = client.account
    local password = args.password

    if account.is_logged then
        console.tell(string.format("%s You are already logged in.", console.colors.yellow), client)
        return
    elseif account.password == nil then
        console.tell(string.format("%s Please register using the command .register <password> <confirm password> to secure your account.", console.colors.yellow), client)
        return
    end

    local status = account:check_password(password)
    if status == CODES.accounts.WrongPassword then
        console.tell(string.format("%s Incorrect password. Please try again using the command .login <password>.", console.colors.red), client)
        return
    end

    console.tell(string.format("%s You have successfully logged in!", console.colors.yellow), client)
end)

console.set_command("kick: username=<string>, reason=[string] -> Kicks the user", {"kick"}, function (args, client)
    local account = client.account
    local kick_username = args.username or ''
    local reason = args.reason or "No reason"
    local kick_account = account_manager.by_username.get_account(kick_username)

    local client_role = account_manager.get_role(account)
    local kick_role = account_manager.get_role(kick_account)

    if not kick_role or not sandbox.by_username.is_online(kick_username) then
        console.tell(string.format('%s The player "%s" is currently offline!', console.colors.red, kick_username), client)
        return
    elseif kick_username == client.player.username then
        console.tell(string.format("%s You cannot kick yourself!", console.colors.red), client)
        return
    elseif not lib.roles.is_higher(client_role, kick_role) then
        console.tell(string.format("%s You cannot interact with this player because their role has a higher or equal priority!", console.colors.red), client)
        return
    end

    local kick_client = account_manager.get_client(kick_account)

    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.Disconnect, reason))
    kick_client.network:send(buffer.bytes)

    console.echo(string.format("%s [%s] Player **%s** has been kicked with reason: %s", console.colors.red, account.username, kick_username, reason))
    kick_client.active = false
end)

console.set_command("role: username=[string] -> Returns the role of the user", {}, function (args, client)
    local username = args.username or client.account.username
    local account = account_manager.by_username.get_account(username)

    if not account or not sandbox.by_username.is_online(username) then
        console.tell(string.format('%s The player "%s" is currently offline!', console.colors.red, username), client)
        return
    end

    console.tell(string.format('%s The role of the player "%s" is: %s', console.colors.yellow, username, account.role), client)
end)

console.set_command("role_set: username=<string>, role=<string> -> Changes the role of the selected player", {"role_management"}, function (args, client)
    local account = client.account
    local subject_username = args.username
    local role = args.role
    local subject_account = account_manager.by_username.get_account(subject_username)

    local client_role = account_manager.get_role(account)
    local subject_role = account_manager.get_role(subject_account)

    if not subject_role or not sandbox.by_username.is_online(subject_username) then
        console.tell(string.format('%s The player "%s" is currently offline!', console.colors.red, subject_username), client)
        return
    elseif subject_username == client.player.username then
        console.tell(string.format("%s You cannot change your own role!", console.colors.red), client)
        return
    elseif not lib.roles.is_higher(client_role, subject_role) then
        console.tell(string.format("%s You cannot interact with this player because their role has a higher or equal priority!", console.colors.red), client)
        return
    elseif not lib.roles.exists(role) then
        console.tell(string.format("%s Role: %s does not exist!", role, console.colors.red), client)
        return
    elseif not lib.roles.is_higher(client_role, CONFIG.roles[role]) then
        console.tell(string.format("%s You can't give a role to a player that's higher than yours!", console.colors.red), client)
        return
    end

    subject_account.role = role

    console.echo(string.format("%s [%s] Player **%s** has been kicked with reason: %s", console.colors.red, account.username, kick_username, reason))
end)

console.set_command("time_set: time=<any> -> Changes day time", {"time_management"}, function (args, client)
    local time = args.time
    local account = client.account

    if not time then
        console.tell(string.format('%s Incorrect time entered! Please enter a number between 0 and 1', console.colors.red), client)
        return
    end

    local status = sandbox.set_day_time(time)
    if status then
        console.echo(string.format('%s [%s] Time has been changed to: %s', console.colors.yellow, account.username, time))
    else
        console.tell(string.format("%s Incorrect time entered! Please enter a number between 0 and 1", console.colors.red), client)
    end
end)