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
        local address, _ = client_socket:get_address()
        if (not table.has(table.freeze_unpack(CONFIG.server.whitelist_ip), address) and #table.freeze_unpack(CONFIG.server.whitelist_ip) > 0) then
            client_socket:close()
            return
        end

        if LAST_SERVER_UPDATE > 0 then
            if os.time() - LAST_SERVER_UPDATE > 20 then
                logger.log('The "pending problem" has been detected. The server is stopped', 'P')

                local tb = debug.get_traceback(1)
                local s = "app.quit() traceback:"
                for i, frame in ipairs(tb) do
                    s = s .. "\n\t"..tb_frame_tostring(frame)
                end
                debug.log(s)
                core.quit()
            end
        end

        print("Pending problem info:")
        print(LAST_SERVER_UPDATE)
        print(os.time())

        table.insert(self.tasks, client_socket)
    end)
end

function server:do_tasks()
    for j=#self.tasks, 1, -1 do
        local client_socket = self.tasks[j]

        local network = Network.new( client_socket )
        local address, port = client_socket:get_address()
        local client = Player.new(false, network, address, port)

        for i=#self.clients, 1, -1 do
            local server_client = self.clients[i]
            if server_client.address == client.address and not server_client.active then
                logger.log("Reconnection from the client side was detected")
                if server_client.network.socket:is_alive() then
                    server_client.network.socket:close()
                end

                table.remove(self.clients, i)
            end
        end

        logger.log("Connection to the client has been successfully established")

        table.insert(self.clients, client)
        table.remove(self.tasks, j)
    end
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
    self:do_tasks()

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