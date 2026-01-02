buf = {}
bincode = {}
bit = {}
bson = {}
ForeignEncode = function () end
ForeignDecode = function () end

-- [[
-- Особенности
--
-- Нельзя использовать цифры в названии переменных, а так же символ X, там, где используется hex запись чисел
-- ]]

--@READ_START

-- @degree.write
-- VARIABLES deg
-- TO_SAVE val
do
    deg = math.clamp(val, -180, 180)

    buf:put_uint24(math.floor((deg + 180) / 360 * 16777215 + 0.5))
end--@

-- @degree.read
-- VARIABLES
-- TO_LOAD a
do
    a = (buf:get_uint24() / 16777215) * 360 - 180
end--@

-- @boolean.write
-- VARIABLES 
-- TO_SAVE val
do
    val = val and true or false
    buf:put_bit(val)
end--@

-- @boolean.read
-- VARIABLES 
-- TO_LOAD result
do
    result = buf:get_bit()
end--@

-- @var.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_bytes(bincode.encode_varint(val))
end--@

-- @var.read
-- VARIABLES 
-- TO_LOAD result
do
    result = bincode.decode_varint(buf)
end--@

-- @any.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_any(val)
end--@

-- @any.read
-- VARIABLES 
-- TO_LOAD result
do
    result = buf:get_any()
end--@

-- @norm8.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_norm8(val)
end--@

-- @norm8.read
-- VARIABLES 
-- TO_LOAD result
do
    result = buf:get_norm8()
end--@

-- @uint12.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_uint(val, 12)
end--@

-- @uint12.read
-- VARIABLES 
-- TO_LOAD result
do
    result = buf:get_uint(12)
end--@

-- @PlayerPos.write
-- VARIABLES xx yy zz y_low y_high
-- TO_SAVE val
do
    xx, yy, zz = unpack(val)
    yy = math.clamp(yy, 0, 262)

    xx = (xx - (xx - xx % 32)) * 1000 + 0.5
    yy = math.floor(yy * 1000 + 0.5)
    zz = (zz - (zz - zz % 32)) * 1000 + 0.5

    y_low = bit.band(yy, 0x1FF)
    y_high = bit.rshift(yy, 9)

    buf:put_uint24(bit.bor(bit.lshift(y_low, 15), xx))
    buf:put_uint24(bit.bor(bit.lshift(zz, 9), y_high))
end--@

-- @PlayerPos.read
-- VARIABLES i ii xx yy zz y_low y_high
-- TO_LOAD result
do
    i = buf:get_uint24()
    ii = buf:get_uint24()

    xx = bit.band(i, 0x7FFF)
    y_low = bit.rshift(i, 15)
    y_high = bit.band(ii, 0x1FF)
    yy = bit.bor(bit.lshift(y_high, 9), y_low)
    zz = bit.rshift(ii, 9)

    result = {x = xx / 1000, y = yy / 1000, z = zz / 1000}
end--@

-- @bson.write
-- VARIABLES 
-- TO_SAVE val
do
    bson.encode(buf, val)
end--@

-- @bson.read
-- VARIABLES 
-- TO_LOAD result
do
    result = bson.decode(buf)
end--@

-- @int8.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_byte(val + 127)
end--@

-- @int8.read
-- VARIABLES 
-- TO_LOAD result
do
    result = buf:get_byte() - 127
end--@

-- @uint8.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_byte(val)
end--@

-- @uint8.read
-- VARIABLES 
-- TO_LOAD result
do
    result = buf:get_byte()
end--@

-- @int16.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_sint16(val)
end--@

-- @int16.read
-- VARIABLES 
-- TO_LOAD result
do
    result = buf:get_sint16()
end--@

-- @uint16.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_uint16(val)
end--@

-- @uint16.read
-- VARIABLES 
-- TO_LOAD result
do
    result = buf:get_uint16()
end--@

-- @int32.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_sint32(val)
end--@

-- @int32.read
-- VARIABLES 
-- TO_LOAD result
do
    result = buf:get_sint32()
end--@

-- @uint32.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_uint32(val)
end--@

-- @uint32.read
-- VARIABLES 
-- TO_LOAD result
do
    result = buf:get_uint32()
end--@

-- @int64.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_int64(val)
end--@

-- @int64.read
-- VARIABLES 
-- TO_LOAD result
do
    result = buf:get_int64()
end--@

-- @f32.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_float32(val)
end--@

-- @f32.read
-- VARIABLES 
-- TO_LOAD result
do
    result = buf:get_float32()
end--@

-- @f64.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_float64(val)
end--@

-- @f64.read
-- VARIABLES 
-- TO_LOAD result
do
    result = buf:get_float64()
end--@

-- @string.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_string(val)
end--@

-- @string.read
-- VARIABLES 
-- TO_LOAD result
do
    result = buf:get_string()
end--@

-- @Array.write
-- VARIABLES i
-- TO_SAVE value
-- FOREIGN
do
    buf:put_bytes(bincode.encode_varint(#value))
    for i = 1, #value do
        Foreign(value[i])
    end
end--@

-- @Array.read
-- VARIABLES i array_length
-- TO_LOAD result
-- FOREIGN
do
    result = {}
    array_length = bincode.decode_varint(buf)

    for i = 1, array_length do
        Foreign(result[i])
    end
end--@

-- @bytearray.write
-- VARIABLES i
-- TO_SAVE arr
do
    buf:put_bytes(bincode.encode_varint(#arr))
    for i = 1, #arr do
        buf:put_byte(arr[i])
    end
end--@

-- @bytearray.read
-- VARIABLES i
-- TO_LOAD result
do
    result = Bytearray()

    for i = 1, bincode.decode_varint(buf) do
        result:append(buf:get_byte())
    end
end--@

-- @Rule.write
-- VARIABLES
-- TO_SAVE data
do
    buf:put_string(data[1])
    buf:put_bit(data[2])
end--@

-- @Rule.read
-- VARIABLES
-- TO_LOAD rule
do
    rule = {
        buf:get_string(),
        buf:get_bit()
    }
end--@

-- @Player.write
-- VARIABLES
-- TO_SAVE data
do
    buf:put_bytes(bincode.encode_varint(data.pid))
    buf:put_string(data.username)
end--@

-- @Player.read
-- VARIABLES
-- TO_LOAD player
do
    player = {
        pid = bincode.decode_varint(buf),
        username = buf:get_string()
    }
end--@

-- @Chunk.write
-- VARIABLES
-- TO_SAVE chunk
do
    buf:put_sint16(chunk.x)
    buf:put_sint16(chunk.z)

    buf:put_bytes(bincode.encode_varint(#chunk.data))
    buf:put_bytes(chunk.data)
end--@

-- @Chunk.read
-- VARIABLES xx zz len
-- TO_LOAD chunk
do
    xx, zz = buf:get_sint16(), buf:get_sint16()
    len = bincode.decode_varint(buf)
    chunk = {
        x = xx,
        z = zz,
        data = buf:get_bytes(len)
    }
end--@

-- @PackHash.write
-- VARIABLES
-- TO_SAVE data
do
    buf:put_string(data.pack)
    buf:put_string(data.hash)
end--@

-- @PackHash.read
-- VARIABLES
-- TO_LOAD data
do
    data = {
        pack = buf:get_string(),
        hash = buf:get_string()
    }
end--@

-- @Particle.write
-- VARIABLES config
-- TO_SAVE value
do
    config = (type(value.origin) == "number" and 1 or 0) + (value.extension and 2 or 0)
    -- 0: origin - позиция, ext нету
    -- 1: origin - uid, ext нету
    -- 2: origin - позиция, ext есть
    -- 3: origin - uid, ext есть

    buf:put_uint32(value.pid)
    buf:put_byte(config)

    --ORIGIN
    if config == 0 or config == 3 then
        buf:put_float32(value.origin[1])
        buf:put_float32(value.origin[2])
        buf:put_float32(value.origin[3])
    else
        buf:put_uint32(value.origin)
    end

    --COUNT
    buf:put_uint16(math.clamp(value.count + 1, 0, MAX_UINT16))

    --PRESET
    bson.encode(buf, value.preset)

    if config == 2 or config == 3 then
        bson.encode(buf, value.extension)
    end
end--@

-- @Particle.read
-- VARIABLES config
-- TO_LOAD value
do
    value = {}
    value.pid = buf:get_uint32()
    config = buf:get_byte()

    --ORIGIN
    if config == 0 or config == 3 then
        value.origin = {
            buf:get_float32(),
            buf:get_float32(),
            buf:get_float32()
        }
    else
        value.origin = buf:get_uint32()
    end

    --COUNT
    value.count = buf:get_uint16() - 1

    --PRESET
    value.preset = bson.decode(buf)

    --EXTENSION
    if config == 2 or config == 3 then
        value.extension = bson.decode(buf)
    end
end--@

-- @particle_origin.write
-- VARIABLES
-- TO_SAVE value
do
    buf:put_uint32(value.pid)
    if type(value.origin) == "number" then
        buf:put_bool(false)
        buf:put_uint32(value.origin)
    else
        buf:put_bool(true)
        buf:put_float32(value.origin[1])
        buf:put_float32(value.origin[2])
        buf:put_float32(value.origin[3])
    end
end--@

-- @particle_origin.read
-- VARIABLES
-- TO_LOAD value
do
    value = {}
    value.pid = buf:get_uint32()
    if not buf:get_bool() then
        value.origin = buf:get_uint32()
    else
        value.origin = {
            buf:get_float32(),
            buf:get_float32(),
            buf:get_float32()
        }
    end
end--@

-- @Audio.write
-- VARIABLES
-- TO_SAVE audio
do
    buf:put_uint32(audio.id)
    buf:put_norm8(audio.volume)

    if audio.x then
        buf:put_bit(true)
        buf:put_float32(audio.x)
        buf:put_float32(audio.y)
        buf:put_float32(audio.z)
    else
        buf:put_bit(false)
    end

    buf:put_float32(audio.velX)
    buf:put_float32(audio.velY)
    buf:put_float32(audio.velZ)

    buf:put_byte(math.clamp(audio.pitch, 0, 255))
    buf:put_string(audio.path)
    buf:put_string(audio.channel)
    buf:put_bit(audio.loop)
    buf:put_bit(audio.isStream or false)
end--@

-- @Audio.read
-- VARIABLES
-- TO_LOAD audio
do
    audio = {}
    audio.id = buf:get_uint32()
    audio.volume = buf:get_norm8()

    if buf:get_bit() then
        audio.x = buf:get_float32()
        audio.y = buf:get_float32()
        audio.z = buf:get_float32()
    end

    audio.velX = buf:get_float32()
    audio.velY = buf:get_float32()
    audio.velZ = buf:get_float32()

    audio.pitch = buf:get_byte()
    audio.path = buf:get_string()
    audio.channel = buf:get_string()
    audio.loop = buf:get_bit()
    audio.isStream = buf:get_bit()
end--@

-- @Vec6.write
-- VARIABLES
-- TO_SAVE vec
-- FOREIGN
do
    Foreign(vec[1])
    Foreign(vec[2])
    Foreign(vec[3])
    Foreign(vec[4])
    Foreign(vec[5])
    Foreign(vec[6])
end--@

-- @Vec6.read
-- VARIABLES
-- TO_LOAD vec
-- FOREIGN
do
    vec = {}
    Foreign(vec[1])
    Foreign(vec[2])
    Foreign(vec[3])
    Foreign(vec[4])
    Foreign(vec[5])
    Foreign(vec[6])
end--@

-- @Vec5.write
-- VARIABLES
-- TO_SAVE vec
-- FOREIGN
do
    Foreign(vec[1])
    Foreign(vec[2])
    Foreign(vec[3])
    Foreign(vec[4])
    Foreign(vec[5])
end--@

-- @Vec5.read
-- VARIABLES
-- TO_LOAD vec
-- FOREIGN
do
    vec = {}
    Foreign(vec[1])
    Foreign(vec[2])
    Foreign(vec[3])
    Foreign(vec[4])
    Foreign(vec[5])
end--@

-- @Vec4.write
-- VARIABLES
-- TO_SAVE vec
-- FOREIGN
do
    Foreign(vec[1])
    Foreign(vec[2])
    Foreign(vec[3])
    Foreign(vec[4])
end--@

-- @Vec4.read
-- VARIABLES
-- TO_LOAD vec
-- FOREIGN
do
    vec = {}
    Foreign(vec[1])
    Foreign(vec[2])
    Foreign(vec[3])
    Foreign(vec[4])
end--@

-- @Vec3.write
-- VARIABLES
-- TO_SAVE vec
-- FOREIGN
do
    Foreign(vec[1])
    Foreign(vec[2])
    Foreign(vec[3])
end--@

-- @Vec3.read
-- VARIABLES
-- TO_LOAD vec
-- FOREIGN
do
    vec = {}
    Foreign(vec[1])
    Foreign(vec[2])
    Foreign(vec[3])
end--@

-- @Vec2.write
-- VARIABLES
-- TO_SAVE vec
-- FOREIGN
do
    Foreign(vec[1])
    Foreign(vec[2])
end--@

-- @Vec2.read
-- VARIABLES
-- TO_LOAD vec
-- FOREIGN
do
    vec = {}
    Foreign(vec[1])
    Foreign(vec[2])
end--@

-- @NullAble.write
-- VARIABLES
-- TO_SAVE val
-- FOREIGN
do
    buf:put_bit(val == nil)
    if val ~= nil then
        Foreign(val)
    end
end--@

-- @NullAble.read
-- VARIABLES
-- TO_LOAD val
-- FOREIGN
do
    val = nil
    if not buf:get_bit() then
        Foreign(val)
    end
end--@

-- @Inventory.write
-- VARIABLES min_count max_count min_id max_id i slot count_ id_ has_meta needed_bits_id needed_bits_count is_empty min_id_bits min_count_bits
-- TO_SAVE inv
do
    is_empty = true
    min_count = math.huge
    max_count = 0

    min_id = math.huge
    max_id = 0

    for i=1, 40 do
        slot = inv[i]
        count_ = slot.count
        id_ = slot.id

        if id_ ~= 0 then
            is_empty = false
            min_count = math.min(min_count, count_)
            max_count = math.max(max_count, count_)

            min_id = math.min(min_id, id_)
            max_id = math.max(max_id, id_)
        end
    end

    buf:put_bit(is_empty)

    needed_bits_id = math.bit_length(max_id-min_id)
    needed_bits_count = math.bit_length(max_count-min_count)

    if is_empty then
        goto continue
    end

    buf:put_uint(needed_bits_id, 4)
    buf:put_uint(needed_bits_count, 4)

    min_id_bits = math.bit_length(min_id)
    min_count_bits = math.bit_length(min_count)

    buf:put_uint(min_id_bits, 4)
    buf:put_uint(min_count_bits, 4)

    buf:put_uint(min_id, min_id_bits)
    buf:put_uint(min_count, min_count_bits)

    for i=1, 40 do
        slot = inv[i]

        if slot.id ~= 0 then
            buf:put_bit(true)
            buf:put_uint(slot.id-min_id, needed_bits_id)
            buf:put_uint(slot.count-min_count, needed_bits_count)

            has_meta = slot.meta ~= nil
            buf:put_bit(has_meta)

            if has_meta then
                bson.encode(buf, slot.meta)
            end
        else
            buf:put_bit(false)
        end
    end

    ::continue::
end--@

-- @Inventory.read
-- VARIABLES needed_bits_id needed_bits_count min_id min_count has_item has_meta slot min_id_bits min_count_bits
-- TO_LOAD inv
do

    if buf:get_bit() then
        inv = table.rep({}, {id = 0, count = 0}, 40)
        goto continue
    end

    needed_bits_id = buf:get_uint(4)
    needed_bits_count = buf:get_uint(4)

    min_id_bits = buf:get_uint(4)
    min_count_bits = buf:get_uint(4)

    min_id = buf:get_uint(min_id_bits)
    min_count = buf:get_uint(min_count_bits)

    inv = {}

    for i = 1, 40 do
        has_item = buf:get_bit()

        if has_item then
            slot = {}

            slot.id = buf:get_uint(needed_bits_id) + min_id
            slot.count = buf:get_uint(needed_bits_count) + min_count

            has_meta = buf:get_bit()

            if has_meta then
                slot.meta = bson.decode(buf)
            end

            inv[i] = slot
        else
            inv[i] = {id = 0, count = 0}
        end
    end

    ::continue::
end--@

-- @PlayerEntity.write
-- VARIABLES has_pos has_rot has_cheats has_item has_additional_information
-- TO_SAVE player

do
    has_pos = player.pos ~= nil
    has_rot = player.rot ~= nil
    has_cheats = player.cheats ~= nil
    has_item = player.hand_item ~= nil
    has_additional_information = 
        player.infinite_items ~= nil or
        player.interaction_distance ~= nil or
        player.instant_destruction ~= nil

    buf:put_bit(has_pos)
    buf:put_bit(has_rot)
    buf:put_bit(has_cheats)
    buf:put_bit(has_item)
    buf:put_bit(has_additional_information)

    if has_pos then
        buf:put_float32(player.pos.x)
        buf:put_float32(player.pos.y)
        buf:put_float32(player.pos.z)
    end

    if has_rot then
        buf:put_uint16(math.floor((math.clamp(player.rot.x, -180, 180) + 180) / 360 * 65535 + 0.5))
        buf:put_uint16(math.floor((math.clamp(player.rot.y, -180, 180) + 180) / 360 * 65535 + 0.5))
        buf:put_uint16(math.floor((math.clamp(player.rot.z, -180, 180) + 180) / 360 * 65535 + 0.5))
    end

    if has_cheats then
        buf:put_bit(player.cheats.noclip)
        buf:put_bit(player.cheats.flight)
    end

    if has_item then
        buf:put_uint16(player.hand_item)
    end

    if has_additional_information then
        buf:put_uint(player.infinite_items == nil and 2 or (player.infinite_items == true and 1 or 0), 2)
        buf:put_uint(player.instant_destruction == nil and 2 or (player.instant_destruction == true and 1 or 0), 2)
        buf:put_uint((player.interaction_distance or -1) + 1, 12)
    end
end--@

-- @PlayerEntity.read
-- VARIABLES has_pos has_rot has_cheats has_additional_information inf_items inst_destruct interact_dist
-- TO_LOAD player
do
    player = {}
    has_pos = buf:get_bit()
    has_rot = buf:get_bit()
    has_cheats = buf:get_bit()
    has_item = buf:get_bit()
    has_additional_information = buf:get_bit()


    if has_pos then
        player.pos = {
            x = buf:get_float32(),
            y = buf:get_float32(),
            z = buf:get_float32()
        }
    end

    if has_rot then
        player.rot = {
            x = (buf:get_uint16() / 65535 * 360) - 180,
            y = (buf:get_uint16() / 65535 * 360) - 180,
            z = (buf:get_uint16() / 65535 * 360) - 180,
        }
    end

    if has_cheats then
        player.cheats = {
            noclip = buf:get_bit(),
            flight = buf:get_bit()
        }
    end

    if has_item then
        player.hand_item = buf:get_uint16()
    end

    if has_additional_information then
        inf_items = buf:get_uint(2)
        inst_destruct = buf:get_uint(2)
        interact_dist = buf:get_uint(12) - 1

        if inf_items ~= 2 then
            player.infinite_items = inf_items == 1 and true or false
        end

        if inst_destruct ~= 2 then
            player.instant_destruction = inst_destruct == 1 and true or false
        end

        if interact_dist > -1 then
            player.interaction_distance = interact_dist
        end
    end
end--@

-- @InventoryUnlimited.write
-- VARIABLES is_empty min_count max_count min_id max_id needed_bits_id needed_bits_count min_id_bits min_count_bits slot i
-- TO_SAVE inv
do
    size = #inv
    buf:put_uint16(size)

    is_empty = true
    min_count = math.huge
    max_count = 0
    min_id = math.huge
    max_id = 0

    for i = 1, size do
        slot = inv[i]
        count = slot.count
        id = slot.id

        if id ~= 0 then
            is_empty = false
            min_count = math.min(min_count, count)
            max_count = math.max(max_count, count)
            min_id = math.min(min_id, id)
            max_id = math.max(max_id, id)
        end
    end

    buf:put_bit(is_empty)

    if is_empty then
        return
    end

    needed_bits_id = math.bit_length(max_id - min_id)
    needed_bits_count = math.bit_length(max_count - min_count)
    min_id_bits = math.bit_length(min_id)
    min_count_bits = math.bit_length(min_count)

    buf:put_uint(needed_bits_id, 4)
    buf:put_uint(needed_bits_count, 4)
    buf:put_uint(min_id_bits, 4)
    buf:put_uint(min_count_bits, 4)
    buf:put_uint(min_id, min_id_bits)
    buf:put_uint(min_count, min_count_bits)

    for i = 1, size do
        slot = inv[i]
        if slot.id ~= 0 then
            buf:put_bit(true)
            buf:put_uint(slot.id - min_id, needed_bits_id)
            buf:put_uint(slot.count - min_count, needed_bits_count)

            has_meta = slot.meta ~= nil
            buf:put_bit(has_meta)
            if has_meta then
                bson.encode(buf, slot.meta)
            end
        else
            buf:put_bit(false)
        end
    end
end--@

-- @InventoryUnlimited.read
-- VARIABLES is_empty needed_bits_id needed_bits_count min_id_bits min_count_bits min_id min_count has_item i size
-- TO_LOAD inv
do
    size = buf:get_uint16()
    is_empty = buf:get_bit()

    if is_empty then
        inv = {}
        for i = 1, size do
            inv[i] = {id = 0, count = 0}
        end
        goto inv_over
    end

    needed_bits_id = buf:get_uint(4)
    needed_bits_count = buf:get_uint(4)
    min_id_bits = buf:get_uint(4)
    min_count_bits = buf:get_uint(4)
    min_id = buf:get_uint(min_id_bits)
    min_count = buf:get_uint(min_count_bits)

    inv = {}

    for i = 1, size do
        has_item = buf:get_bit()
        if has_item then
            slot = {
                id = buf:get_uint(needed_bits_id) + min_id,
                count = buf:get_uint(needed_bits_count) + min_count
            }

            if buf:get_bit() then
                slot.meta = bson.decode(buf)
            end
            inv[i] = slot
        else
            inv[i] = {id = 0, count = 0}
        end
    end

    ::inv_over::
end--@

-- @Edd.write
-- VARIABLES 
-- TO_SAVE val
do
    edd.encode(buf, val)
end--@

-- @Edd.read
-- VARIABLES 
-- TO_LOAD result
do
    result = edd.decode(buf)
end--@