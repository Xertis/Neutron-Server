local protocol = require "multiplayer/protocol-kernel/protocol"
local List = require "lib/public/common/list"

local Player = {}
local max_id = 0
Player.__index = Player

function Player.new(active, network, address, port, username)
    local self = setmetatable({}, Player)

    self.active = false or active
    self.network = network
    self.username = username
    self.address = address
    self.port = port
    self.client_id = max_id
    self.account = nil
    self.player = nil
    self.ping = {ping = 0, last_upd = time.uptime(), waiting = false}
    self.meta = {}
    self.is_kicked = false

    self.response_queue = List.new()
    self.received_packets = List.new()

    max_id = max_id + 1

    return self
end

function Player:is_active()
    return self.active
end

function Player:kick()
    self.is_kicked = true
    self.active = false
end

function Player:set_account(account)
    self.account = account
end

function Player:set_player(player)
    self.player = player
end

function Player:set_active(new_value)
    self.active = new_value
end

function Player:push_packet(...)
    local bytes = protocol.build_packet("server", ...)
    self:queue_response(bytes)
end

function Player:queue_response(event)
    List.pushright(self.response_queue, event)
end

return Player