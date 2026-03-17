local sandbox = require "api/v2/sandbox"
local accounts = require "api/v2/accounts"

function on_share(player, invid, slotid)
    local blockinv = sandbox.inventories.get_second_inventory(player)
    local account = accounts.by_identity.get_account(player.identity)
    local rules = accounts.roles.get_rules(account)

    if blockinv ~= nil then
        inventory.move(invid, slotid, blockinv)
    elseif rules["allow-content-access"] then
        inventory.set(invid, slotid, 0, 0)
    elseif slotid < 10 then
        inventory.move_range(invid, slotid, invid, 10)
    else
        inventory.move_range(invid, slotid, invid, 0, 9)
    end
end
