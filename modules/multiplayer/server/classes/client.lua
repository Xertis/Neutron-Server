local protocol = require "multiplayer/protocol-kernel/protocol"
local List = require "lib/public/common/list"
local interceptors = require "api/v2/interceptors"

local Client = {}
local max_id = 0
Client.__index = Client

function Client.new(active, network, address, port, username)
    local self = setmetatable({}, Client)

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

function Client:is_active()
    return self.active
end

function Client:kick()
    self.is_kicked = true
    self.active = false
end

function Client:set_account(account)
    self.account = account
end

function Client:set_player(player)
    self.player = player
end

function Client:set_active(new_value)
    self.active = new_value
end

function Client:interceptor_process(packet_type, data)
    return interceptors.send.__process(self, packet_type, data)
end

function Client:push_packet(packet_type, data)
    local status = interceptors.send.__process(self, packet_type, data)

    if status then
        local bytes = protocol.build_packet("server", packet_type, data)
        self:queue_response(bytes)
    end
end

function Client:queue_response(event)
    List.pushright(self.response_queue, event)
end

return Client