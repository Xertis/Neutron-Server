local protect = require "lib/private/protect"
if protect.protect_require() then return end

local metadata = start_require "lib/private/files/metadata"
local lib = require "lib/private/min"
local account = {}
account.__index = account

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
    metadata.accounts.set(self.username, self:to_save())
end

function account:save()
    metadata.accounts.set(self.username, self:to_save())
end

function account:set_password(password)
    if type(password)[1] ~= 's' then
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
    if self.active == true then
        return CODES.accounts.WithoutChanges
    end

    local data = metadata.accounts.get(self.username)
    if not data then
        return CODES.accounts.DataLoss
    end

    self.active = true
    account:to_load(data)
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
    self.username = data.username
    self.password = data.password
    self.role = data.role
    self.ip = data.ip
end

return account