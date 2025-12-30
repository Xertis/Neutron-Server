local protect = require "lib/private/protect"
if protect.protect_require() then return end

local Account = require "lib/private/accounts/account"
local sandbox = require "lib/private/sandbox/sandbox"
local container = require "lib/private/common/container"
local module = {
    by_username = {},
    by_identity = {}
}

function module.login(identity)
    logger.log(string.format('account [#%s] is logging in...', logger.shorted(identity)))

    local account = Account.new(identity) or container.get_all(identity).account
    local status = account:revive()

    if status == CODES.accounts.ReviveSuccess or status == CODES.accounts.WithoutChanges then
        -- Ну мы его разбудили правильно, ничего делать не надо, мы молодцы
    elseif status == CODES.accounts.DataLoss then
        account:set("role", CONFIG.roles.default_role)
        account:set("active", true)
    end

    if account:is_active() and container.accounts.get(account.identity) == nil then
        container.accounts.put(account.identity, account)
    end

    account:save()

    return account
end

function module.leave(client)
    local account = client.account;

    logger.log(string.format('account [#%s] left...', logger.shorted(account.identity)))

    local date = os.date("*t");
    date.yday, date.wday, date.isdst, date.sec = nil, nil, nil, nil;

    if account.is_logged then
        account:set("last_session", {
            ip = client.address,
            timestamp = date,
        });
    end

    account:abort()

    local player = container.player_online.get(account.identity)

    sandbox.leave_player(player)
    container.accounts.put(account.identity, nil)

    return account
end

function module.get_role(account)
    if not account then
        return nil
    end

    return CONFIG.roles[account.role]
end

function module.get_client(account)
    if not account then
        error("Invalid account")
    end

    for _, client in pairs(container.clients_all.get()) do
        if not client.account then
            logger.log("Account information lost.", "E")
            goto continue
        end
        if client.account.identity == account.identity then
            return client
        end

        ::continue::
    end
end

function module.by_identity.get_account(identity)
    if not identity then
        return nil
    end

    return container.accounts.get(identity)
end

function module.by_identity.get_client(identity)
    for _, client in pairs(container.clients_all.get()) do
        if client.account.identity == identity then
            return client
        end
    end
end

function module.get_rules(account, category)
    if not category then
        category = "game_rules"
    elseif category == true then
        category = "server_rules"
    end

    return CONFIG.roles[account.role][category]
end

return module
