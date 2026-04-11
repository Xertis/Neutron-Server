local metadata = import "lib/data/metadata"
local Player = {}
Player.__index = Player

local players_proxy = metadata.proxy("players")

function Player.new(username, identity)
    local self = setmetatable({}, Player)

    self.username = username
    self.identity = identity
    self.active = false
    self.entity_id = nil
    self.pid = nil
    self.world = nil
    self.region_pos = { x = 0, z = 0 }
    self.invid = 0
    self.pending_inventories = {}
    self.temp = {}

    return self
end

function Player:is_active()
    return self.active
end

function Player:abort()
    self.active = false
    self:save()
end

function Player:save()
    players_proxy[self.identity] = self:to_save()
end

function Player:revive()
    if self.active then
        return CODES.players.WithoutChanges
    end

    local data = players_proxy[self.identity]
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
        identity = self.identity,
        username = self.username,
        world = self.world,
        pid = self.pid,
        invid = self.invid,
        region_pos = self.region_pos
    }
end

function Player:to_load(data)
    self.identity = data.identity
    self.username = data.username
    self.world = data.world
    self.pid = data.pid
    self.invid = data.invid
    self.region_pos = data.region_pos or { x = 0, z = 0 }
end

return Player
