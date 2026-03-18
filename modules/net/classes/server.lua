local Client = import "net/classes/client"
local container = import "core/container"
local main_pipe = import "net/pipelines/main"
local http_pipe = import "net/pipelines/http"
local server_echo = import "lib/flow/server_echo"
local server_matches = import "net/handlers/main"
local protocol = import "net/protocol/protocol"

local server = {}
server.__index = server

function server.new(port)
    local self = setmetatable({}, server)

    self.port = port

    self.main_clients = {}
    self.http_clients = {}
    self.main_socket = nil
    self.http_socket = nil
    self.tps = { timestamp = time.uptime(), tick = 0, target_tps = TARGET_TPS }
    self.tasks = {}
    container.clients_all.set(self.main_clients)

    return self
end

function server:start_main()
    logger.log(string.format("Starting main server on port: %s", self.port))
    self.main_socket = network.tcp_open(self.port, function(client_socket)
        client_socket:set_nodelay(true)
        local address, _ = client_socket:get_address()

        if (not table.has(table.freeze_unpack(CONFIG.server.whitelist_ip), address) and #table.freeze_unpack(CONFIG.server.whitelist_ip) > 0) then
            client_socket:close()
            return
        end

        if table.has(self.tasks, client_socket) then
            client_socket:close()
            logger.log(
                "The client is trying to reconnect while its previous session is still active and queued for processing. Aborted",
                "W")
            return
        end

        table.insert(self.tasks, { socket = client_socket, storage = self.main_clients })
    end)
end

function server:start_http()
    local http_port = self.port + 1
    logger.log(string.format("Starting http server on port: %s", http_port))

    self.http_socket = network.tcp_open(http_port, function(client_socket)
        client_socket:set_nodelay(true)
        local address, _ = client_socket:get_address()

        if (not table.has(table.freeze_unpack(CONFIG.server.whitelist_ip), address) and #table.freeze_unpack(CONFIG.server.whitelist_ip) > 0) then
            client_socket:close()
            return
        end

        if table.has(self.tasks, client_socket) then
            client_socket:close()
            logger.log(
                "The client is trying to reconnect while its previous session is still active and queued for processing. Aborted",
                "W")
            return
        end

        table.insert(self.tasks, { socket = client_socket, storage = self.http_clients })
    end)
end

function server:do_tasks()
    for j = #self.tasks, 1, -1 do
        local client_socket = self.tasks[j].socket
        local storage = self.tasks[j].storage

        local address, port = client_socket:get_address()
        local client = Client.new(false, client_socket, address, port)

        for i = #storage, 1, -1 do
            local server_client = storage[i]
            if server_client.address == client.address and not server_client.active then
                logger.log("Reconnection from the client side was detected", "W")
                if server_client.socket:is_alive() then
                    server_client.socket:close()
                end

                table.remove(storage, i)
            end
        end

        logger.log("Connection to the client has been successfully established")

        table.insert(storage, client)
        table.remove(self.tasks, j)
    end
end

function server:stop()
    self.main_socket:close()
end

function server:calculate_tps()
    local tps_data = self.tps;
    local tps = TPS;

    tps_data.tick = tps_data.tick + 1;

    if tps_data.tick == tps_data.target_tps then
        tps_data.tick = 0;

        local cur_time = time.uptime();
        local diff = os.difftime(cur_time, tps_data.timestamp);

        tps.tps = tps_data.target_tps / diff;
        tps.mspt = diff / tps_data.target_tps * 1000;

        tps_data.timestamp = time.uptime();
    end
end

function server:tick()
    self:calculate_tps()
    self:do_tasks()

    local cur_time = time.uptime()
    local max_timeout = CONFIG.server.kick_threshold_timeout or 30

    for id, clients in ipairs({ self.main_clients, self.http_clients }) do
        for index = #clients, 1, -1 do
            local client = clients[index]
            local socket = client.socket

            if not socket or
                not socket:is_alive() or
                client.is_kicked or
                cur_time - client.ping.last_upd > max_timeout then
                if client.active then
                    client.active = false
                end

                table.remove(clients, index)

                if id == 1 then
                    server_matches.client_online_handler:switch(
                        protocol.ClientMsg.Disconnect,
                        { packet_type = protocol.ClientMsg.Disconnect },
                        client
                    )
                end

                if socket and socket:is_alive() then
                    socket:close()
                end
            end
        end
    end

    main_pipe:process(table.copy(self.main_clients))
    http_pipe:process(table.copy(self.http_clients))
    server_echo.proccess(self.main_clients)
end

return server
