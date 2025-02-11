local protect = require "lib/private/protect"

if protect.protect_require() then return end

local metadata = require "lib/private/files/metadata"
local lib = require "lib/private/min"
local Player = {}
Player.__index = Player

function Player.new(username, password)
    local self = setmetatable({}, Player)
    password = password or "000000"

    self.active = false
    self.username = username
    self.password = lib.hash.sha256(password)
    self.entity_id = nil
    self.pid = nil
    self.role = nil

    return self
end

function Player:is_active()
    return self.active
end

function Player:abort()
    self.active = false
    metadata.players.set(self.username, Player:to_save())
end

function Player:revive()
    local data = metadata.players.get(self.username)
    if not data then
        return SANDBOX.codes.players.DataLoss
    end

    if self.password == data.password or not CONFIG.server.password_auth then
        self.active = true
        Player:to_load(data)
        return SANDBOX.codes.players.ReviveSuccess
    end

    return SANDBOX.codes.players.WrongPassword
end

function Player:to_save()
    return {
        username = self.username,
        password = self.password,
        entity_id = self.entity_id,
        role = self.role
    }
end

function Player:to_load(data)
    self.username = data.username
    self.password = data.password
    self.entity_id = data.entity_id
    self.role = data.role
end

return Player