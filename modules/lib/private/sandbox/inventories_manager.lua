local protect = require "lib/private/protect"
local protocol = require "multiplayer/protocol-kernel/protocol"
local account_manager = require "lib/private/accounts/account_manager"
local sandbox = require "lib/private/sandbox/sandbox"

local module = {}

-- id = общий идентификатор инвентаря (у клиента и у сервера)
-- invid = локальный идентификатор инвентаря
local id2Invid = {}
local invid2Id = {}
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
    return table.set_default(id2Invid, player.identity, {})[id]
end

local function invidToId(player, invid)
    return table.set_default(invid2Id, player.identity, {})[invid]
end

local function open_inventory(player, invid, id)
    table.set_default(id2Invid, player.identity, {})[id] = invid
    table.set_default(id2Invid, player.identity, {})[invid] = id
end

local function close_inventory(player, invid)
    local id = table.set_default(id2Invid, player.identity, {})[invid]

    table.set_default(id2Invid, player.identity, {})[invid] = nil
    table.set_default(id2Invid, player.identity, {})[id] = nil
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
function module.open_block(player, pos)
    local invid = inventory.get_block(pos[1], pos[2], pos[3])
    if invid == 0 then return end
    local id = table.max_index(id2Invid[player.identity])
    open_inventory(player, invid, id)
    local client = sandbox.get_client(player)
    client:push_packet(protocol.ServerMsg.OpenBlockInventory, {
        inventory_id = id,
        pos = {
            x = pos[1],
            y = pos[2],
            z = pos[3]
        }
    })
end

function module.open_virtual(player, layout, disable_player_inventory, root_id, id)
    -- Пока не работает, невозможно реализовать
end

function module.close_inventory_by_invid(player, invid)
    close_inventory(invid)
    local client = sandbox.get_client(player)
    client:push_packet(protocol.ServerMsg.CloseInventory, {
        inventory_id = invidToId(player, invid),
    })
end

function module.close_inventory_by_id(player, id)
    close_inventory(idToInvid(player, id))
    local client = sandbox.get_client(player)
    client:push_packet(protocol.ServerMsg.CloseInventory, {
        inventory_id = id,
    })
end

function module.init(_player)
    open_inventory(_player, player.get_inventory(_player.pid), 1)
    open_inventory(_player, -1, 0)
end

function module.sync(player, id)
    local client = sandbox.get_client(player)

    if id ~= 0 then
        client:push_packet(protocol.ServerMsg.SyncInventory, {
            inventory_id = id,
            inventory = inventory.get_inv(idToInvid(player, id))
        })
    end

    client:push_packet(protocol.ServerMsg.SyncInventory, {
        inventory_id = -1,
        inventory = { get_server_cursor(player) }
    })
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

function module.interact(player, id, slot, action, item_id, client_checksum)
    if action == 2 or action == 3 then return end

    local client = sandbox.get_client(player)
    local grabbed = get_server_cursor(player)
    local stack = { id = 0, count = 0, meta = nil }
    local invid = idToInvid(player, id)

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

    if client_checksum then
        local current_server_checksum = server_checksum(player, id)
        if current_server_checksum ~= client_checksum then
            module.sync(player, id)
        end
    end

    return true
end

return protect.protect_return(module)
