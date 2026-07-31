local Account = import "core/accounts/classes/account"
local sandbox = import "core/sandbox/methods"
local container = import "core/container"
local module = {
    by_username = {},
    by_identity = {}
}

function module.login(identity)
    logger.log(string.format('account [#%s] is logging in...', logger.shorted(identity)))

    local account = Account.new(identity)

    if account.role == nil then
        account.role = CONFIG.roles.default_role
    end

    container.accounts.put(account.identity, account)

    return account
end

function module.leave(client)
    local account = client.account;

    logger.log(string.format('account [#%s] left...', logger.shorted(account.identity)))

    local date = os.date("*t");
    date.yday, date.wday, date.isdst, date.sec = nil, nil, nil, nil;

    if account.is_logged then
        account.last_session = {
            ip = client.address,
            timestamp = date,
        }
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

function module.get_permissions(account)
    local role = module.get_role(account)
    if not role then return end

    return role.permissions
end

return module
