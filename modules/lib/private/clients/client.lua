local protect = require "lib/private/protect"
if protect.protect_require() then return end

local metadata = require "lib/private/files/metadata"
local lib = require "lib/private/min"
local Client = {}
Client.__index = Client

function Client.new(username, password)
    local self = setmetatable({}, Client)
    password = password or ""

    self.username = username
    self.password = lib.hash.sha256(password)
    self.active = false
    self.role = nil

    return self
end

function Client:is_active()
    return self.active
end

function Client:abort()
    self.active = false
    metadata.clients.set(self.username, self:to_save())
end

function Client:save()
    metadata.clients.set(self.username, self:to_save())
end

function Client:revive()
    if self.active == true then
        return CODES.clients.WithoutChanges
    end

    local data = metadata.clients.get(self.username)
    if not data then
        return CODES.clients.DataLoss
    end

    if self.password == data.password or not CONFIG.server.password_auth then
        self.active = true
        Client:to_load(data)
        return CODES.clients.ReviveSuccess
    end

    return CODES.clients.WrongPassword
end

function Client:set(key, val)
    self[key] = val
end

function Client:to_save()
    return {
        username = self.username,
        password = self.password,
        role = self.role
    }
end

function Client:to_load(data)
    self.username = data.username
    self.password = data.password
    self.role = data.role
end

return Client