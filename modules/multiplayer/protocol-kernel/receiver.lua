local module = {}

local next_id = 0

local function rem_elems(tbl, startIndex)

    for i=#tbl, startIndex, -1 do
        table.remove(tbl, i)
    end

    return tbl
end

function module.create_buffer()
    return {
        storage = {},
        next_id = next_id + 1,
        len = 0
    }
end

function module.recv(buffer, client)
    next_id = next_id + 1
    local socket = client.network.socket

    if not socket then return end
    local count = socket:available()
    if count == 0 then
        return
    end

    module.__apppend(buffer, socket:recv(count, true))
end

function module.__apppend(buffer, bytes)
    local storage = buffer.storage
    buffer.len = buffer.len + #bytes

    for i=1, #bytes do
        table.insert(storage, 1, bytes[i])
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
    rem_elems(buffer.storage, start)
    buffer.len = #buffer.storage
end

function module.empty(buffer)
    buffer.storage = {}
    buffer.len = 0
end

return module

