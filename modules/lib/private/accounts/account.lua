local protect = require "lib/private/protect"
if protect.protect_require() then return end

local metadata = require "lib/private/files/metadata"
local lib = require "lib/private/min"
local account = {}
account.__index = account

function account.new(username, password, ip)
    local self = setmetatable({}, account)
    password = password or ""

    self.username = username
    self.password = lib.hash.sha256(password)
    self.active = false
    self.ip = ip
    self.role = nil

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

function account:revive()
    if self.active == true then
        return CODES.accounts.WithoutChanges
    end

    local data = metadata.accounts.get(self.username)
    if not data then
        return CODES.accounts.DataLoss
    end

    if self.password == data.password or not CONFIG.server.password_auth then
        self.active = true
        account:to_load(data)
        return CODES.accounts.ReviveSuccess
    end

    return CODES.accounts.WrongPassword
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