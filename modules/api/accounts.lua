local account_manager = start_require("server:lib/private/accounts/account_manager")
local lib = require "lib/private/min"
local module = {
    roles = {}
}

function module.get_account_by_name(username)
    return account_manager.by_username.get_account(username)
end

function module.get_client(account)
    return account_manager.get_client(account)
end

function module.kick(account)
    if not account.username then
        error("Invalid account")
    end

    account_manager.leave(account)
end

function module.roles.get(account)
    return account_manager.get_role(account)
end

function module.roles.get_rules(account, category)
    return account_manager.get_rules(account, category)
end

function module.roles.is_higher(role1, role2)
    return lib.roles.is_higher(role1, role2)
end

function module.roles.exists(role)
    return lib.roles.exists(role)
end

return module