local module = {}

local next_id = 0

function module.create_buffer()
    return {
        storage = Bytearray(),
        next_id = next_id + 1,
        len = 0
    }
end

function module.recv(buffer, client)
    next_id = next_id + 1
    local socket = client.network.socket

    if not socket then return end

    module.__apppend(buffer, socket:recv(socket:available()))
end

function module.__apppend(buffer, bytes)
    bytes = bytes or {}
    local len_bytes_line = #bytes

    if len_bytes_line == 0 then return end

    local storage = buffer.storage
    buffer.len = buffer.len + len_bytes_line

    for i=1, #bytes do
        storage:insert(1, bytes[i])
    end
end

function module.get(buffer, pos)
    local inverse_pos = buffer.len-pos+1
    if inverse_pos > 0 and inverse_pos <= buffer.len then
        local byte = buffer.storage[inverse_pos]
        return byte
    end
end

function module.len(buffer)
    return buffer.len
end

function module.print(buffer)
    print(table.tostring(table.freeze_unpack(buffer)))
end

function module.clear(buffer, pos)
    local start = buffer.len-pos+1
    buffer.storage:remove(start, buffer.len-start+1)
    buffer.len = start-1
end

function module.empty(buffer)
    buffer.storage = Bytearray()
    buffer.len = 0
end

return module

