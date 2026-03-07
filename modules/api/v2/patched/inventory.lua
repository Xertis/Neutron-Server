local inventories_manager = start_require("server:lib/private/sandbox/inventories_manager")

local global_inventory = _G["inventory"]

PACK_ENV["inventory"] = table.deep_copy(global_inventory)

local inventory_funcs = {
    set = inventory.set,
    set_count = inventory.set_count,
    add = inventory.add,
    set_data = inventory.set_data,
}

for name, func in pairs(inventory_funcs) do
    global_inventory[name] = function(invid, ...)
        inventories_manager.echo_sync(invid)

        return func(invid, ...)
    end
end

local move = inventory.move
local move_range = inventory.move_range
local remove = inventory.remove

function global_inventory.move(invA, slotA, invB, slotB)
    inventories_manager.echo_sync(invA)
    inventories_manager.echo_sync(invB)
    return move(invA, slotA, invB, slotB)
end

function global_inventory.move_range(invA, slotA, invB, rangeBegin, rangeEnd)
    inventories_manager.echo_sync(invA)
    inventories_manager.echo_sync(invB)
    return move_range(invA, slotA, invB, rangeBegin, rangeEnd)
end

function global_inventory.remove(invid)
    inventories_manager.echo_sync(invid, nil, false)
    return remove(invid)
end
