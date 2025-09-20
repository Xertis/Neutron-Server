local account_manager = start_require "server:lib/private/accounts/account_manager"
local protocol = start_require "server:multiplayer/protocol-kernel/protocol"
local entities_manager = start_require "lib/private/entities/entities_manager"
local tasks = require "api/v1/tasks"
local lib = require "lib/private/min"
local module = {
    roles = {}
}

function module.get_account_by_name(username)
    return account_manager.by_username.get_account(username)
end

function module.get_client(account)
    return account_manager.get_client(account)
end

function module.get_client_by_name(username)
    return account_manager.by_username.get_client(username)
end

function module.kick(account, reason, is_soft)
    local function kick()
        if not account.username then
            error("Invalid account")
        end

        local client = account_manager.get_client(account)

        client:push_packet(protocol.ServerMsg.Disconnect, reason or "No reason")
        logger.log(string.format('The account "%s" was kicked for the reason: %s', account.username, reason))

        entities_manager.clear_pid(client.player.pid)
        client:kick()
    end

    if is_soft then
        tasks.add_task(kick)
    else
        kick()
    end
end

function module.roles.get(account)
    return account_manager.get_role(account)
end

function module.roles.get_rules(account, category)
    return account_manager.get_rules(account, category)
end

function module.roles.is_higher(role1, role2)
    return lib.roles.is_higher(role1, role2)
end

function module.roles.exists(role)
    return lib.roles.exists(role)
end

return module