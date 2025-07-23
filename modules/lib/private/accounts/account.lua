local protect = require "lib/private/protect"
if protect.protect_require() then return end

local metadata = start_require "lib/private/files/metadata"
local lib = require "lib/private/min"
local account = {}
account.__index = account

local accounts_proxy = metadata.proxy("server", "accounts")

function account.new(username)
    local self = setmetatable({}, account)

    self.username = username
    self.active = false
    self.ip = nil
    self.is_logged = false
    self.role = nil
    self.password = nil

    return self
end

function account:is_active()
    return self.active
end

function account:abort()
    self.active = false
    self:save()
end

function account:save()
    accounts_proxy[self.username] = self:to_save()
end

function account:set_password(password)
    if type(password) ~= 'string' then
        return CODES.accounts.PasswordUnvalidated
    elseif #password < 8 then
        return CODES.accounts.PasswordUnvalidated
    end

    self.password = lib.hash.sha256(password)
    self:save()
end

function account:check_password(password)
    if lib.hash.sha256(password) ~= self.password then
        return CODES.accounts.WrongPassword
    end

    self.is_logged = true
    return CODES.accounts.CorrectPassword
end

function account:revive()
    if self.active then
        return CODES.accounts.WithoutChanges
    end

    local data = accounts_proxy[self.username]
    if not data then
        return CODES.accounts.DataLoss
    end

    self.active = true
    self:to_load(data)

    if not CONFIG.roles[self.role] then
        local default_role = CONFIG.roles.default_role
        logger.log(string.format(
            [["%s" account has a non-existent "%s" role, his role has been changed to: "%s"]],
            self.username, self.role, default_role),
        "W")
        self.role = default_role
    end

    return CODES.accounts.ReviveSuccess
end

function account:set(key, val)
    self[key] = val
end

function account:to_save()
    return {
        username = self.username,
        password = self.password,
        role = self.role,
        ip = self.ip
    }
end

function account:to_load(data)
    for k, v in pairs(data) do
        self[k] = v
    end
end

return account