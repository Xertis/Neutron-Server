local sandbox = start_require("server:lib/private/sandbox/sandbox")
local account_manager = start_require("server:lib/private/accounts/account_manager")

local module = {
    players = {},
    world = {}
}

function module.players.get_all()
    local players = sandbox.get_players()

    return players
end

function module.players.get_player(account)
    return sandbox.get_player(account)
end

function module.players.set_pos(player, pos)
    local client = account_manager.by_username.get_account(player.username)
    player.set_pos(player.pid, pos.x, pos.y, pos.z)

    local state = sandbox.get_player_state(player)

    local DATA = {pos.x, pos.y, pos.z, state.yaw, state.pitch, state.noclip, state.flight}
    local buf = protocol.create_databuffer()
    buf:put_packet(protocol.build_packet("server", protocol.ServerMsg.SynchronizePlayerPosition, unpack(DATA)))
    client.network:send(buf.bytes)
end

function module.players.get_in_radius(target_pos, radius)
    target_pos = target_pos or {}

    if not target_pos.x or not radius then
        error("missing position or radius")
    end

    local res = {}
    local x, y, z = target_pos.x, target_pos.y, target_pos.z

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

return module