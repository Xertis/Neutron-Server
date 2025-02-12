local protect = require "lib/private/protect"
if protect.protect_require() then return end

local Account = require "lib/private/accounts/account"
local container = require "lib/private/common/container"
local module = {}

function module.login(username, password)
    logger.log(string.format('account "%s" is logging...', username))

    local account = Account.new(username, password) or container.get_all(username).account
    local status = account:revive()

    if status == CODES.accounts.ReviveSuccess or status == CODES.accounts.WithoutChanges then
        -- Ну мы его разбудили правильно, ничего делать не надо, мы молодцы
    elseif status == CODES.accounts.WrongPassword then
        logger.log(string.format('account "%s" entered an incorrect password.', account.username))
        return
    elseif status == CODES.accounts.DataLoss then
        account:set("role", CONFIG.roles.default_role)
        account:set("active", true)
    end

    if account:is_active() and container.get_all(account.username).account == nil then
        container.put(account.username, account, "account")
    end

    account:save()

    return account
end

return module