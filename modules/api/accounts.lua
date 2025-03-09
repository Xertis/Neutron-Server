local account_manager = start_require("server:lib/private/accounts/account_manager")
local module = {}

function module.get_account_by_name(username)
    return account_manager.by_username.get_account(username)
end

function module.get_client(account)
    return account_manager.get_client(account)
end

return module