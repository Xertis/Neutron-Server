local protect = require "lib/private/protect"

if protect.protect_require() then return end

local metadata = start_require "lib/private/files/metadata"
local Player = {}
Player.__index = Player

function Player.new(username)
    local self = setmetatable({}, Player)

    self.username = username
    self.active = false
    self.entity_id = nil
    self.pid = nil
    self.world = nil
    self.is_teleported = false
    self.region_pos = {x = 0, z = 0}
    self.invid = 0
    self.inv_is_changed = false
    self.current_weather = nil

    return self
end

function Player:is_active()
    return self.active
end

function Player:abort()
    self.active = false
    metadata.players.set(self.username, self:to_save())
end

function Player:save()
    metadata.players.set(self.username, self:to_save())
end

function Player:revive()

    if self.active == true then
        return CODES.players.WithoutChanges
    end

    local data = metadata.players.get(self.username)
    if not data then
        return CODES.players.DataLoss
    end

    self.active = true
    self:to_load(data)
    return CODES.players.ReviveSuccess
end

function Player:set(key, val)
    self[key] = val
end

function Player:to_save()
    return {
        username = self.username,
        entity_id = self.entity_id,
        world = self.world,
        pid = self.pid,
        invid = self.invid
    }
end

function Player:to_load(data)
    self.username = data.username
    self.entity_id = data.entity_id
    self.world = data.world
    self.pid = data.pid
    self.invid = data.invid
end

return Player