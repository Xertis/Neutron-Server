local sandbox = require "lib/private/sandbox/sandbox"
local account_manager = require "lib/private/accounts/account_manager"
local lib = require "lib/private/min"
local console = require "api/v2/console"

console.set_command("tell: username=<string> message=<string> -> Sends a private message to a specific player", {},
    function(args, client)
        local username = args.username
        local sender_username = client.player.username
        local message = args.message
        local receiver_client = sandbox.get_client(sandbox.by_username.get(username))
        local receiver_account = receiver_client.account

        if not receiver_account or not sandbox.by_identity.is_online(receiver_account.identity) then
            console.tell(string.format('%s The player "%s" is currently offline!', console.colors.red, username), client)
            return
        end

        local yellow, white = console.colors.yellow, console.colors.white

        console.tell(string.format("%s[you -> %s] %s %s", yellow, username, white, message), client)
        console.tell(string.format("%s[%s -> you] %s %s", yellow, sender_username, white, message), receiver_client)
    end)

console.set_command("list: -> Shows a list of online players", {}, function(args, client)
    local players = table.keys(sandbox.get_players())

    local message = "Online players"
    console.tell(string.format("%s %s: %s", console.colors.white, message, table.tostring(players)), client)
end)

console.set_command("ping: -> Shows the response time", {}, function(args, client)
    console.tell(string.format("Ping: %sms", client.ping.ping), client)
end)

console.set_command("tps: -> Shows current tps and mspt", {}, function(args, client)
    local color = (TPS.tps > TARGET_TPS - (TARGET_TPS / 8) and console.colors.green)
        or (TPS.tps > TARGET_TPS and console.colors.yellow)
        or console.colors.red
    local tps = string.format("%s%s%s", color, TPS.tps, console.colors.white);
    local mspt = string.format("%s%sms%s", color, TPS.mspt, console.colors.white);

    console.tell(string.format("TPS: %s | MSPT: %s", tps, mspt), client);
end)

console.set_command("obama: -> Shows current tps and mspt", {}, function(args, client)
    _G["player"].set_name(client.player.pid, "obama")
end)

console.set_command("register: password=<string>, rpassword=<string> -> Registration", {}, function(args, client)
    local account = client.account
    local passwords = { args.password, args.rpassword }

    if not CONFIG.server.password_auth then
        console.tell(string.format("%s Built-in authorization in Neutron is disabled.", console.colors.red), client)
        return
    end

    if account.is_logged then
        console.tell(string.format("%s You are already logged in.", console.colors.yellow), client)
        return
    elseif account.password ~= nil then
        console.tell(
            string.format("%s Please log in using the command .login <password> to access your account.",
                console.colors.yellow), client)
        return
    end

    if passwords[1] ~= passwords[2] then
        console.tell(
            string.format("%s The passwords you entered do not match. Please try again using the command .register",
                console.colors.red), client)
        return
    end

    local status = account:set_password(passwords[1])

    if status == CODES.accounts.PasswordUnvalidated then
        console.tell(
            string.format("%s Your password does not meet the requirements, create a new one.", console.colors.red),
            client)
        return
    end

    account.is_logged = true
    console.tell(string.format("%s You have successfully registered!", console.colors.yellow), client)
end, true)

console.set_command("login: password=<string> -> Logging", {}, function(args, client)
    local account = client.account
    local password = args.password

    if not CONFIG.server.password_auth then
        console.tell(string.format("%s Built-in authorization in Neutron is disabled.", console.colors.red), client)
        return
    end

    if account.is_logged then
        console.tell(string.format("%s You are already logged in.", console.colors.yellow), client)
        return
    elseif account.password == nil then
        console.tell(
            string.format(
                "%s Please register using the command .register <password> <confirm password> to secure your account.",
                console.colors.yellow), client)
        return
    end

    local status = account:check_password(password)
    if status == CODES.accounts.WrongPassword then
        console.tell(
            string.format("%s Incorrect password. Please try again using the command .login <password>.",
                console.colors.red),
            client)
        return
    end

    console.tell(string.format("%s You have successfully logged in!", console.colors.yellow), client)
end, true)

console.set_command("role: username=[string] -> Returns the role of the user", {}, function(args, client)
    local username = args.username or client.player.username
    local target_client = sandbox.get_client(sandbox.by_username.get(username))
    local account = target_client.account

    if not account or not sandbox.by_identity.is_online(account.identity) then
        console.tell(string.format('%s The player "%s" is currently offline!', console.colors.red, username), client)
        return
    end

    console.tell(string.format('%s The role of the player "%s" is: %s', console.colors.yellow, username, account.role),
        client)
end)

console.set_command("role_set: username=<string>, role=<string> -> Changes the role of the selected player",
    { server = { "role_management" } }, function(args, client)
        local account = client.account
        local subject_username = args.username
        local role = args.role
        local subject_client = sandbox.get_client(sandbox.by_username.get(subject_username))
        local subject_account = subject_client.account

        local client_role = account_manager.get_role(account)
        local subject_role = account_manager.get_role(subject_account)

        if not subject_role or not sandbox.by_identity.is_online(subject_account.identity) then
            console.tell(string.format('%s The player "%s" is currently offline!', console.colors.red, subject_username),
                client)
            return
        elseif subject_username == client.player.username then
            console.tell(string.format("%s You cannot change your own role!", console.colors.red), client)
            return
        elseif not lib.roles.is_higher(client_role, subject_role) then
            console.tell(
                string.format(
                    "%s You cannot interact with this player because their role has a higher or equal priority!",
                    console.colors.red), client)
            return
        elseif not lib.roles.exists(role) then
            console.tell(string.format("%s Role: %s does not exist!", role, console.colors.red), client)
            return
        elseif not lib.roles.is_higher(client_role, CONFIG.roles[role]) then
            console.tell(
                string.format("%s You can't give a role to a player that's higher than yours!", console.colors.red),
                client)
            return
        end

        subject_account.role = role
    end)

console.set_command("time_set: time=<any> -> Changes day time", { server = { "time_management" } },
    function(args, client)
        local time = args.time
        local username = client.player.username

        if not time then
            console.tell(
                string.format('%s Incorrect time entered! Please enter a number between 0 and 1', console.colors.red),
                client)
            return
        end

        local status = sandbox.set_day_time(time)
        if status then
            console.echo(string.format('%s [%s] Time has been changed to: %s', console.colors.yellow, username,
                time))
        else
            console.tell(
                string.format("%s Incorrect time entered! Please enter a number between 0 and 1", console.colors.red),
                client)
        end
    end)
