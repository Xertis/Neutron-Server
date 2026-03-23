local Network = {}
Network.__index = Network

local VirtualSocket = import "net/classes/virtual_socket"


function Network.new(side, callback, err_callback)
    local self = setmetatable({}, Network)

    self.side = side
    self.callback = callback
    self.err_callback = err_callback

    return self
end

function Network:tcp_open(port)
    self.port = port
    self.socket = network.tcp_open(port, self.callback)

    return self.socket
end

function Network:tcp_connect(address, port)
    self.socket = network.tcp_connect(address, port, self.callback, self.err_callback)

    return self.socket
end

function Network:virtual_connect()
    if self.side == "client" then
        self.callback(VirtualSocket("server:__packets_handler", "client:__packets_handler"))
    else
        self.callback(VirtualSocket("client:__packets_handler", "server:__packets_handler"))
    end
end

return Network
