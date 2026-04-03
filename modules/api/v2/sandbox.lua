local sandbox = import("server:core/sandbox/methods")
local inventories_managers = import("server:core/sandbox/managers/inventories")
local account_manager = import("server:core/accounts/methods")
local protocol = import("server:net/protocol/protocol")

local InventoryController = import "server:core/sandbox/classes/inventory_controller"

local module = {
    players = {
        by_username = {},
        by_identity = {}
    },
    world = {},
    blocks = {},
    inventories = {}
}

function module.players.is_username_available(username, identity)
    return sandbox.is_username_available(username, identity)
end

function module.players.get_client(player)
    return sandbox.get_client(player)
end

function module.players.get_all()
    local players = sandbox.get_players()

    return players
end

function module.players.get_player(account)
    return sandbox.get_player(account)
end

function module.players.by_username.is_online(username)
    return sandbox.by_username.is_online(username)
end

function module.players.by_identity.is_online(identity)
    return sandbox.by_identity.is_online(identity)
end

function module.players.get_in_radius(target_pos, radius)
    target_pos = target_pos or {}

    if not target_pos[1] or not radius then
        error("missing position or radius")
    end

    local res = {}
    local x, y, z = unpack(target_pos)

    for key, _player in pairs(sandbox.get_players()) do
        local x2, y2, z2 = player.get_pos(_player.pid)

        if math.euclidian3D(x, y, z, x2, y2, z2) <= radius then
            res[key] = _player
        end
    end

    return res
end

function module.players.get_by_pid(pid)
    local pid_type = type(pid)
    if pid_type ~= "number" then
        error("pid (number) expected, got " .. pid_type)
    end

    for _, _player in pairs(sandbox.get_players()) do
        if _player.pid == pid then
            return _player
        end
    end
end

function module.inventories.create_controller(source)
    return InventoryController.new(source)
end

function module.inventories.set_controller(ident, controller)
    if type(ident) == "number" then
        inventories_managers.set_block_inventory_controller(ident, controller)
    else
        inventories_managers.set_virtual_inventory_controller(ident, controller)
    end
end

function module.inventories.open_block(player, pos)
    return inventories_managers.open_block(player, pos)
end

function module.inventories.open(player, layout_path, disable_player_inventory, root_id)
    return inventories_managers.open_virtual(player, layout_path, disable_player_inventory, root_id)
end

function module.inventories.close(player)
    inventories_managers.close_inventory(player)
end

function module.inventories.echo_close(invid)
    inventories_managers.echo_close_inventory(invid)
end

function module.inventories.get_second_inventory(player)
    return inventories_managers.get_second_inventory(player)
end

return module
