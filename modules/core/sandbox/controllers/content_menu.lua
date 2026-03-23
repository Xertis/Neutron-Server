function on_share(_player, _, _, item_id)
    if not IS_HEADLESS then return end
    local inv = player.get_inventory(_player.pid)
    local size = inventory.size(inv)
    local stack_size = item.stack_size(item_id)

    for slot = 0, size - 1 do
        local id, count = inventory.get(inv, slot)
        if id == item_id and count < stack_size then
            inventory.set_count(inv, slot, count + 1)
            return
        end
    end

    for slot = 0, size - 1 do
        local id, count = inventory.get(inv, slot)
        if id == 0 then
            inventory.set(inv, slot, item_id, 1)
            return
        end
    end
end
