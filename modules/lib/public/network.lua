local socketlib = require "lib/public/socketlib"

local Network = {}
Network.__index = Network

function Network.new(socket)
    local self = setmetatable({}, Network)

    self.socket = socket or nil

    return self
end

function Network:connect(host, port, callback)

    socketlib.connect(host, port, function(sock)
        self.socket = sock
        callback(true)
    end,
    function (err)
        callback(false)
    end)
end

function Network:disconnect()
    if self.socket then
        socketlib.close_socket( self.socket )
        self.socket = nil
    end
end

function Network:alive()
    if self.socket and self.socket:is_alive() then
        return true
    end
    return false
end

function Network:send(data)
    if self.socket and self.socket:is_alive() then
        socketlib.send( self.socket, data )
    end
end

function Network:recieve(length)

    if self.socket then
        local data = socketlib.receive_text( self.socket, length or 1024 )
        return data
    end
end

function Network:recieve_bytes(length)
    length = length or 1024
    local tries = 0
    local max_tries_count = 1

    if not self.socket then return end

    local bytes = socketlib.receive(self.socket, length) or {}

    while #bytes < length and tries <= max_tries_count do
        coroutine.yield()
        local data = socketlib.receive(self.socket, math.max(length - #bytes, 0))
        table.merge(bytes, data or {})
        tries = tries + (not data and 1 or 0)
    end

    return #bytes > 0 and bytes or nil
end

return Network