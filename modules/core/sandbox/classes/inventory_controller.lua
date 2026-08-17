local InventoryController = {}
InventoryController.__index = InventoryController

function InventoryController.new(source)
    local self = setmetatable({}, InventoryController)

    self.env = { _G = _G }
    setmetatable(self.env, { __index = _G })

    if type(source) == "string" then
        __load_script(source, true, self.env)
    elseif type(source) == "table" then
        table.merge(self.env, source)
    else
        error("InventoryController:load - source must be string or table")
    end

    return self
end

function InventoryController:add_global_variable(key, val)
    self.env[key] = val
end

function InventoryController:__on_open(player, invid, x, y, z)
    -- Если инвентарь виртуальный - x, y, z будут равны nil
    local on_open = self.env.on_open
    if not on_open then return end

    on_open(player, invid, x, y, z)
end

function InventoryController:__on_close(player, invid)
    local on_close = self.env.on_close
    if not on_close then return end

    on_close(player, invid)
end

function InventoryController:__on_update(player, invid, slot, action, mode)
    local on_update = self.env.on_update
    if not on_update then return end

    on_update(player, invid, slot, action, mode)
end

function InventoryController:__on_share(player, invid, slot, item_id)
    local on_share = self.env.on_share
    if not on_share then return end

    on_share(player, invid, slot, item_id)
end

function InventoryController:__on_attach(player, invid)
    local on_attach = self.env.on_attach
    if not on_attach then return end

    on_attach(player, invid)
end

function InventoryController:__on_detach(player, invid)
    local on_detach = self.env.on_detach
    if not on_detach then return end

    on_detach(player, invid)
end

return InventoryController
