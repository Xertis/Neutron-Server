local metadata = import "lib/data/metadata"
local Player = {}

local TEMPED_DEFAULTS = {
    temp = function() return {} end,
    pending_inventories = function() return {} end,
    entity_observers = function() return {} end,
    predicted_observers = function() return {} end,
    entity_id = -1,
    view_distance = VIEW_DISTANCE,
    view_padding = VIEW_PADDING_DEFAULT,
    is_crouching = false
}

local TEMPED_DATA = {}
for key in pairs(TEMPED_DEFAULTS) do
    TEMPED_DATA[key] = setmetatable({}, { __mode = "k" })
end

function Player.__index(self, key)
    local storage = TEMPED_DATA[key]
    if storage then
        local value = storage[self]
        if value == nil then
            local default = TEMPED_DEFAULTS[key]
            if type(default) == "function" then
                value = default()
                storage[self] = value
            else
                value = default
            end
        end
        return value
    end
    return Player[key]
end

function Player.__newindex(self, key, value)
    local storage = TEMPED_DATA[key]
    if storage then
        storage[self] = value
    else
        rawset(self, key, value)
    end
end

local players_proxy = metadata.proxy("players")

function Player.new(username, identity)
    local self = players_proxy[identity]

    if not self then
        self = {
            username = username,
            identity = identity,
            active = false,
            pid = nil,
            world = nil,
            region_pos = { x = 0, y = 0, z = 0 },
            invid = 0,
            rules = {}
        }
        players_proxy[identity] = self
    end

    self.rules = self.rules or {}

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
