local bson = require "lib/common/bson"
local bb = require "lib/common/bit_buffer"
local module = {}

function module.serialize(inv)
    local buf = bb:new()
    local is_empty = true
    local min_count = math.huge
    local max_count = 0

    local min_id = math.huge
    local max_id = 0

    buf:put_uint16(#inv)

    for i=1, #inv do
        local slot = inv[i]
        local count = slot.count
        local id = slot.id

        if id ~= 0 then
            is_empty = false
            min_count = math.min(min_count, count)
            max_count = math.max(max_count, count)

            min_id = math.min(min_id, id)
            max_id = math.max(max_id, id)
        end
    end

    buf:put_bit(is_empty)

    local needed_bits_id = math.bit_length(max_id-min_id)
    local needed_bits_count = math.bit_length(max_count-min_count)

    if is_empty then
        goto continue
    end

    buf:put_uint(needed_bits_id, 4)
    buf:put_uint(needed_bits_count, 4)

    local max_id_bits = math.bit_length(max_id)
    local max_count_bits = math.bit_length(max_count)

    buf:put_uint(max_id_bits, 4)
    buf:put_uint(max_count_bits, 4)

    buf:put_uint(min_id, max_id_bits)
    buf:put_uint(min_count, max_count_bits)

    for i=1, #inv do
        local slot = inv[i]

        if slot.id ~= 0 then
            buf:put_bit(true)
            buf:put_uint(slot.id-min_id, needed_bits_id)
            buf:put_uint(slot.count-min_count, needed_bits_count)

            local has_meta = slot.meta ~= nil
            buf:put_bit(has_meta)

            if has_meta then
                bson.encode(buf, slot.meta)
            end
        else
            buf:put_bit(false)
        end
    end

    ::continue::

    buf:flush()
    return buf.bytes
end

function module.deserialize(bytes)
    local buf = bb:new(bytes)

    local size = buf:get_uint16()

    if buf:get_bit() then
        return table.rep({}, {id = 0, count = 0}, size)
    end

    local needed_bits_id = buf:get_uint(4)
    local needed_bits_count = buf:get_uint(4)

    local max_id_bits = buf:get_uint(4)
    local max_count_bits = buf:get_uint(4)

    local min_id = buf:get_uint(max_id_bits)
    local min_count = buf:get_uint(max_count_bits)

    local inv = {}

    for i = 1, size do
        local has_item = buf:get_bit()

        if has_item then
            local slot = {}

            slot.id = buf:get_uint(needed_bits_id) + min_id
            slot.count = buf:get_uint(needed_bits_count) + min_count

            local has_meta = buf:get_bit()

            if has_meta then
                slot.meta = bson.decode(buf)
            end

            inv[i] = slot
        else
            inv[i] = {id = 0, count = 0}
        end
    end

    return inv
end

return module