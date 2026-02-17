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

    storage:append(bytes)
end

function module.get(buffer, pos)
    if pos > 0 and pos <= buffer.len then
        return buffer.storage[pos]
    end
end

function module.len(buffer)
    return buffer.len
end

function module.print(buffer)
    print(table.tostring(table.freeze_unpack(buffer)))
end

function module.clear(buffer, pos)
    local storage = buffer.storage
    local n = #storage
    local new_len = n - pos

    buffer.len = new_len

    if pos <= 0 then return storage end
    if pos >= n then
        storage:remove(1, n)
        return storage
    end
    for i = 1, new_len do
        storage[i] = storage[i + pos]
    end

    storage:remove(new_len + 1, n - new_len)
end

function module.empty(buffer)
    buffer.storage:clear()
    buffer.len = 0
end

return module

