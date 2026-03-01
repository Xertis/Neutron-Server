local sandbox = start_require("server:lib/private/sandbox/sandbox")

local global_inventory = _G["inventory"]

PACK_ENV["inventory"] = table.deep_copy(global_inventory)

local inventory_funcs = {
    set = inventory.set,
    set_count = inventory.set_count,
    add = inventory.add,
    remove = inventory.remove,
    set_data = inventory.set_data,
    decrement = inventory.decrement,
    use = inventory.use,
    set_all_data = inventory.set_all_data,
    set_caption = inventory.set_caption,
    set_description = inventory.set_description,
}

local function set_changed_flag(invid)
    local player = sandbox.by_invid.get(invid)

    if player then
        player.inv_is_changed = true
    end
end

for name, func in pairs(inventory_funcs) do
    global_inventory[name] = function(invid, ...)
        set_changed_flag(invid)

        return func(invid, ...)
    end
end

local move = inventory.move
local move_range = inventory.move_range

function global_inventory.move(invA, slotA, invB, slotB)
    set_changed_flag(invA)
    set_changed_flag(invB)
    return move(invA, slotA, invB, slotB)
end

function global_inventory.move_range(invA, slotA, invB, rangeBegin, rangeEnd)
    set_changed_flag(invA)
    set_changed_flag(invB)
    move_range(invA, slotA, invB, rangeBegin, rangeEnd)
end
