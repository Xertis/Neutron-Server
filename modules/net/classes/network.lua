local Network = {}
Network.__index = Network


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

return Network
