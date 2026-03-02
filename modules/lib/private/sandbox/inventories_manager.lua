local protect = require "lib/private/protect"
local protocol = require "multiplayer/protocol-kernel/protocol"
local account_manager = require "lib/private/accounts/account_manager"
local sandbox = require "lib/private/sandbox/sandbox"

local module = {}

-- id = общий идентификатор инвентаря (у клиента и у сервера)
-- invid = локальный идентификатор инвентаря
local id2Invid = {}
local invid2Id = {}
local block_controllers = {}
local server_cursors = {}

local function get_server_cursor(player)
    if not server_cursors[player.identity] then
        server_cursors[player.identity] = { id = 0, count = 0, meta = nil }
    end
    return server_cursors[player.identity]
end

local function set_server_cursor(player, item_data)
    server_cursors[player.identity] = item_data
end

local function idToInvid(player, id)
    return table.set_default(id2Invid, player.identity, {})[id].invid
end

local function invidToId(player, invid)
    return table.set_default(invid2Id, player.identity, {})[invid].id
end

local function get_controller(player, invid)
    return table.set_default(invid2Id, player.identity, {})[invid].controller
end

local function close_inventory(player, invid)
    local p_id2Invid = table.set_default(id2Invid, player.identity, {})
    local p_invid2Id = table.set_default(invid2Id, player.identity, {})

    local id = p_id2Invid[invid]

    local controller = get_controller(player, invid)
    if controller then controller:__on_close(player, invid) end

    if p_id2Invid[id] then p_invid2Id[p_id2Invid[id].invid] = nil end
    if p_invid2Id[invid] then p_id2Invid[p_invid2Id[invid].id] = nil end
end

local function server_checksum(player, id)
    local invid = idToInvid(player, id)
    local inv = {}

    if invid and id ~= 0 then
        inv = inventory.get_inv(invid)
    end

    local cursor = get_server_cursor(player)
    return table.checksum({ inv, cursor })
end

-- id = айди на сервере
-- invid = айди для клиента
local function open_inventory(player, invid, id, controller)
    local p_id2Invid = table.set_default(id2Invid, player.identity, {})
    local p_invid2Id = table.set_default(invid2Id, player.identity, {})

    if p_id2Invid[id] then p_invid2Id[p_id2Invid[id].invid] = nil end
    if p_invid2Id[invid] then p_id2Invid[p_invid2Id[invid].id] = nil end

    p_id2Invid[id] = { invid = invid, controller = controller }
    p_invid2Id[invid] = { id = id, controller = controller }
end

function module.get_second_inventory(player)
    local p_id2Invid = id2Invid[player.identity]

    if not p_id2Invid then
        return
    end

    for id, data in pairs(p_id2Invid) do
        if id ~= 0 and id ~= 1 then
            return data.invid
        end
    end
end

function module.open_block(player, pos)
    local x, y, z = pos[1], pos[2], pos[3]
    local invid = inventory.get_block(x, y, z)
    if invid == 0 then return 0 end

    local p_data = id2Invid[player.identity] or {}
    local new_id = table.max_index(p_data) + 1

    local block_id = block.get(x, y, z)
    local controller = block_controllers[block_id]

    if controller then
        controller:__on_open(player, invid, x, y, z)
    end

    open_inventory(player, invid, new_id, controller)

    local client = sandbox.get_client(player)
    client:push_packet(protocol.ServerMsg.OpenBlockInventory, {
        inventory_id = new_id,
        pos = { x = x, y = y, z = z }
    })
    module.sync(player, new_id)

    return invid
end

function module.open_virtual(player, layout, disable_player_inventory, root_id, id)
    -- Пока не работает, невозможно реализовать
end

function module.close_inventory_by_invid(player, invid)
    local client = sandbox.get_client(player)
    client:push_packet(protocol.ServerMsg.InventoryClose, {
        inventory_id = invidToId(player, invid),
    })
    close_inventory(player, invid)
end

function module.close_inventory_by_id(player, id, non_sync)
    close_inventory(player, idToInvid(player, id))

    if not non_sync then
        local client = sandbox.get_client(player)
        client:push_packet(protocol.ServerMsg.InventoryClose, {
            inventory_id = id,
        })
    end
end

function module.init(_player, pinv_controller, minv_controller)
    open_inventory(_player, player.get_inventory(_player.pid), 1, pinv_controller)
    open_inventory(_player, -1, 0, minv_controller)
end

function module.sync(player, ...)
    local client = sandbox.get_client(player)

    for _, id in pairs({ ... }) do
        if id ~= 0 then
            client:push_packet(protocol.ServerMsg.InventorySync, {
                inventory_id = id,
                inventory = inventory.get_inv(idToInvid(player, id))
            })
        end
    end

    client:push_packet(protocol.ServerMsg.InventorySync, {
        inventory_id = -1,
        inventory = { get_server_cursor(player) }
    })
end

function module.echo_sync(invid, without_identity)
    for identity, inventories in pairs(invid2Id) do
        local data = inventories[invid]

        if data and identity ~= without_identity then
            local target_player = sandbox.by_identity.get_player(identity)
            if target_player then
                target_player.pending_inventories[data.id] = true
            end
        end
    end
end

local function set_item(invid, slot, item_data)
    if item_data.id then
        inventory.set(invid, slot, item_data.id, item_data.count)
    end

    if item_data.meta then
        for name, value in pairs(item_data.meta) do
            inventory.set_data(invid, slot, name, value)
        end
    end
end

local function get_item(invid, slot)
    local id, count = inventory.get(invid, slot)
    local meta = inventory.get_all_data(invid, slot)
    return { id = id, count = count, meta = meta }
end

function module.set_block_inventory_controller(id, controller)
    block_controllers[id] = controller
end

function module.interact(player, id, slot, action, item_id, client_checksum)
    local client = sandbox.get_client(player)
    local grabbed = get_server_cursor(player)
    local stack = { id = 0, count = 0, meta = nil }
    local invid = idToInvid(player, id)

    if not invid then
        logger.log(
            string.format('Player "%s" [#%s] tried to use unopened inventory. Aborting operation.',
                client.player.username, client.player.identity), "W")
        return
    end

    if id == 0 then
        local rules = account_manager.get_rules(client.account)
        if not rules["allow-content-access"] then return false end

        stack = { id = item_id, count = 1, meta = nil }
    else
        if not invid then return false end
        stack = get_item(invid, slot)
    end

    if action == 0 then
        if id == 0 then
            if grabbed.id == 0 or grabbed.count == 0 then
                grabbed = { id = stack.id, count = 1, meta = stack.meta }
            else
                grabbed = { id = 0, count = 0, meta = nil }
            end
        else
            if grabbed.id == 0 or grabbed.count == 0 then
                if stack.count > 0 then
                    grabbed = { id = stack.id, count = stack.count, meta = stack.meta }
                    stack = { id = 0, count = 0, meta = nil }
                end
            elseif stack.id == 0 or stack.count == 0 then
                stack = { id = grabbed.id, count = grabbed.count, meta = grabbed.meta }
                grabbed = { id = 0, count = 0, meta = nil }
            elseif stack.id == grabbed.id then
                local max_stack = item.stack_size(stack.id)
                local free_space = max_stack - stack.count

                if free_space > 0 then
                    if grabbed.count <= free_space then
                        stack.count = stack.count + grabbed.count
                        grabbed = { id = 0, count = 0, meta = nil }
                    else
                        stack.count = max_stack
                        grabbed.count = grabbed.count - free_space
                    end
                end
            else
                local temp = { id = stack.id, count = stack.count, meta = stack.meta }
                stack = { id = grabbed.id, count = grabbed.count, meta = grabbed.meta }
                grabbed = temp
            end
        end
    elseif action == 1 then
        if id == 0 then
            return false
        end

        if grabbed.id == 0 or grabbed.count == 0 then
            if stack.count > 0 then
                local half = math.floor(stack.count / 2)
                local taken = stack.count - half

                grabbed = { id = stack.id, count = taken, meta = stack.meta }
                stack.count = half
                if stack.count == 0 then stack.id = 0 end
            end
        else
            if stack.id == 0 or stack.count == 0 then
                stack = { id = grabbed.id, count = 1, meta = grabbed.meta }
                grabbed.count = grabbed.count - 1
            elseif stack.id == grabbed.id then
                local max_stack = item.stack_size(stack.id)
                if stack.count < max_stack then
                    stack.count = stack.count + 1
                    grabbed.count = grabbed.count - 1
                end
            end

            if grabbed.count == 0 then grabbed = { id = 0, count = 0, meta = nil } end
        end
    end

    set_server_cursor(player, grabbed)
    if id ~= 0 then
        set_item(invid, slot, stack)
    end

    local controller = get_controller(player, invid)
    if (action == 0 or action == 1) and controller then
        controller:__on_update(player, invid, slot, action)
    elseif controller then
        controller:__on_share(player, invid, slot, item_id)
    end

    if client_checksum then
        local current_server_checksum = server_checksum(player, id)
        if current_server_checksum ~= client_checksum then
            module.sync(player, id)
        end
    end

    module.echo_sync(invid, player.identity)

    return true
end

return protect.protect_return(module)
