local state_machine = {}
state_machine.__index = state_machine

function state_machine.new(func)
    local self = setmetatable({}, state_machine)

    self.values = {} -- Таблица всех значений, добавленных в стейт-машину.
    self.func = func

    return self
end

function state_machine:send(val)
    table.insert(self.values, val)
    local res = self.func(self.values)

    return res
end

return state_machine