local VirtualSocket = {}
VirtualSocket.__index = {
    send         = function(self, bytes)
        events.emit(self._send_event, bytes)
    end,

    recv         = function(self, length, usetable)
        local chunk = self._buf:slice(1, length)
        self._buf:remove(1, length)
        if not usetable then return chunk end
        return table.from_bytearray(chunk)
    end,

    close        = function(self) self._alive = false end,
    available    = function(self) return #self._buf end,
    is_alive     = function(self) return self._alive end,
    is_connected = function(self) return self._alive end,
    get_address  = function(self) return "127.0.0.1" end,
    set_nodelay  = function(self, _) end,
    is_nodelay   = function(self) return true end,
}

setmetatable(VirtualSocket, {
    __call = function(cls, send_event, recv_event)
        local self = setmetatable({
            _buf        = Bytearray(),
            _alive      = true,
            _send_event = send_event,
        }, cls)

        events.on(recv_event, function(bytes)
            self._buf:append(bytes)
        end)

        return self
    end
})

return VirtualSocket
