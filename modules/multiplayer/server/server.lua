local protect = require "lib/private/protect"
local socketlib = require "lib/public/socketlib"
local Player = require "multiplayer/server/classes/player"
local Network = require "lib/public/network"
local container = require "lib/private/common/container"
local server_pipe = require "multiplayer/server/server_pipe"
local server_echo = require "multiplayer/server/server_echo"
local account_manager = require "lib/private/accounts/account_manager"
local server_matches = require "multiplayer/server/server_matches"
local protocol = require "lib/public/protocol"

local server = {}
server.__index = server

function server.new(port)
    local self = setmetatable({}, server)

    self.port = port

    self.clients = {}
    self.server_socket = nil
    container.clients_all.set(self.clients)

    return self
end

function server:start()
    self.server_socket = socketlib.create_server(self.port, function(client_socket)
        logger.log("Connection request received")
        local network = Network.new( client_socket )
        local address, port = client_socket:get_address()
        local client = Player.new(false, network, address, port)

        for i, mclient in ipairs(self.clients) do
            if mclient.address == client.address and not self.clients[i].active then
                self.clients[i].network = client.network
                self.clients[i].port = client.port
                return
            end
        end

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
    for index, client in ipairs(self.clients) do
        local socket = client.network.socket
        if socket and socket:is_alive() then
            server_pipe:process(client)
        else
            if client.active then
                client.active = false
            end
            table.remove_value(self.clients, client)

            server_matches.client_online_handler:switch(protocol.ClientMsg.Disconnect, {}, client)
        end
    end

    server_echo.proccess(self.clients)
end

return protect.protect_return(server)