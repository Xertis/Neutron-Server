local protect = require "lib/private/protect"

if protect.protect_require() then return end

local module = {}
local states = {}

local id = 0
local State = {}
State.__index = State

function State.new(name)
    local self = setmetatable({}, State)

    self.im_a_state = true

    self.name = name
    self.data = {}
    self.client = nil
    self.id = id
    id = id + 1

    return self
end

function State:update_data(key, val)
    self.data[key] = val
end

function State:get_data(key)
    if not key then
        return self.data
    end

    return self.data[key]
end

function State:clear()
    states[self.client] = nil
    self.client = nil
end

function State:move_to(new_state)
    new_state:__set(self.client)
    new_state.data = self.data
    self:clear()
    states[new_state.client] = new_state
end

function State:__set(client)
    states[client] = self
    self.client = client
end

function module.create_state(name)
    return State.new(name)
end

function module.get_state(client)
    return states[client]
end

return module