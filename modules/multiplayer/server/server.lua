local protect = require "lib/private/protect"
local socketlib = require "lib/public/socketlib"
local Player = require "multiplayer/server/classes/player"
local Network = require "lib/public/network"
local container = require "lib/private/common/container"
local server_pipe = require "multiplayer/server/server_pipe"
local server_echo = require "multiplayer/server/server_echo"
local server_matches = require "multiplayer/server/server_matches"
local protocol = require "multiplayer/protocol-kernel/protocol"

local server = {}
server.__index = server

function server.new(port)
    local self = setmetatable({}, server)

    self.port = port

    self.clients = {}
    self.server_socket = nil
    self.tasks = {}
    container.clients_all.set(self.clients)

    return self
end

function server:start()
    self.server_socket = socketlib.create_server(self.port, function(client_socket)
        local network = Network.new( client_socket )
        local address, port = client_socket:get_address()
        local client = Player.new(false, network, address, port)

        for i, server_client in ipairs(self.clients) do
            if server_client.address == client.address and not server_client.active then
                logger.log("Reconnection from the client side was detected")
                self.clients[i].network = client.network
                self.clients[i].port = client.port
                self.clients[i].is_kicked = client.is_kicked
                return
            end
        end

        logger.log("Connection to the client has been successfully established")

        table.insert(self.clients, client)
    end)
end

function server:queue_response(event)
    for index, client in ipairs(self.clients) do
        client:queue_response(event)
    end
end

function server:stop()
    self.server_socket:close()
end

function server:tick()
    for index=#self.clients, 1, -1 do
        local client = self.clients[index]
        local socket = client.network.socket
        if not socket or not socket:is_alive() or client.is_kicked then
            if client.active then
                client.active = false
            end

            table.remove(self.clients, index)

            server_matches.client_online_handler:switch(
                protocol.ClientMsg.Disconnect,
                {packet_type = protocol.ClientMsg.Disconnect},
                client
            )

            if socket and socket:is_alive() then
                socket:close()
            end

        end
    end

    server_pipe:process(table.copy(self.clients))

    server_echo.proccess(self.clients)
end

return protect.protect_return(server)