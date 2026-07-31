local metadata = import "lib/data/metadata"
local Player = {}

local TEMP = {}

function Player.__index(self, key)
    if key == "temp" then
        local t = TEMP[self]
        if not t then
            t = {}
            TEMP[self] = t
        end
        return t
    end
    return Player[key]
end

local players_proxy = metadata.proxy("players")

function Player.new(username, identity)
    local self = players_proxy[identity]

    if not self then
        self = {
            username = username,
            identity = identity,
            active = false,
            entity_id = nil,
            pid = nil,
            world = nil,
            region_pos = { x = 0, y = 0, z = 0 },
            view_distance = VIEW_DISTANCE,
            view_padding = VIEW_PADDING_DEFAULT,
            entity_observers = {},
            invid = 0,
            pending_inventories = {},
            is_crouching = false,
            rules = {}
        }
        players_proxy[identity] = self
    end

    self.active = true

    return setmetatable(self, Player)
end

function Player:is_active()
    return self.active
end

function Player:abort()
    self.active = false
end

return Player
