local protect = require "lib/private/protect"
if protect.protect_require() then return end

local Account = require "lib/private/accounts/account"
local sandbox = require "lib/private/sandbox/sandbox"
local container = require "lib/private/common/container"
local module = {
    by_username = {}
}

function module.login(username)
    logger.log(string.format('account "%s" is logging...', username))

    if table.has(table.freeze_unpack(RESERVED_USERNAMES), username:lower()) then
        logger.log(string.format('The username "%s" is reserved for the system and cannot be used by a client.', username))
        return
    end

    local account = Account.new(username) or container.get_all(username).account
    local status = account:revive()

    if status == CODES.accounts.ReviveSuccess or status == CODES.accounts.WithoutChanges then
        -- Ну мы его разбудили правильно, ничего делать не надо, мы молодцы
    elseif status == CODES.accounts.DataLoss then
        account:set("role", CONFIG.roles.default_role)
        account:set("active", true)
    end

    if account:is_active() and container.accounts.get(account.username) == nil then
        container.accounts.put(account.username, account)
    end

    account:save()

    return account
end

function module.by_username.get_account(name)
    if not name then
        return nil
    end

    return container.accounts.get(name)
end

function module.leave(account)
    logger.log(string.format('account "%s" is leaving...', account.username))
    account:abort()

    local player = container.player_online.get(account.username)

    sandbox.leave_player(player)
    container.accounts.put(account.username, nil)

    return account
end

function module.get_role(account)
    if not account then
        return nil
    end

    return CONFIG.roles[account.role]
end

function module.get_client(account)
    for _, client in pairs(container.clients_all.get()) do
        if client.account.username == account.username then
            return client
        end
    end
end

function module.get_rules(account, root)
    if not root then
        root = "game_rules"
    elseif root == true then
        root = "server_rules"
    end

    return CONFIG.roles[account.role][root]
end

return module