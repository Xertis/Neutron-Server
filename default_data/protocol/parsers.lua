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

-- @player_pos.write
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

-- @player_pos.read
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

-- @array.write
-- VARIABLES i
-- TO_SAVE value
-- TO_LOOPED data_type
do
    buf:put_bytes(bincode.encode_varint(#value))
    for i = 1, #value do
        ForeignEncode(data_type, value[i])
    end
end--@

-- @array.read
-- VARIABLES i array_length
-- TO_LOAD result
-- TO_LOOPED data_type
do
    result = {}
    array_length = bincode.decode_varint(buf)

    for i = 1, array_length do
        ForeignDecode(data_type, result[i])
    end
end--@

-- @Chunk.write
-- VARIABLES
-- TO_SAVE data
do
    buf:put_sint16(data[1])
    buf:put_sint16(data[2])
    buf:put_bytes(bincode.encode_varint(#data[3]))
    buf:put_bytes(data[3])
end--@

-- @Chunk.read
-- VARIABLES
-- TO_LOAD chunk
do
    chunk = {
        buf:get_sint16(),
        buf:get_sint16(),
        buf:get_bytes(bincode.decode_varint(buf)),
    }
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
    buf:put_uint32(data[1])
    buf:put_string(data[2])
end--@

-- @Player.read
-- VARIABLES
-- TO_LOAD player
do
    player = {
        buf:get_uint32(),
        buf:get_string()
    }
end--@

-- @particle.write
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

-- @particle.read
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

-- @vec3.write
-- VARIABLES i
-- TO_SAVE vec
-- TO_LOOPED data_type
do
    for i=1, 3 do
        ForeignEncode(data_type, vec[i])
    end
end--@

-- @vec3.read
-- VARIABLES i
-- TO_LOAD result
-- TO_LOOPED data_type
do
    result = {}
    for i=1, 3 do
        ForeignDecode(data_type, result[i])
    end
end--@

-- @Inventory.write
-- VARIABLES min_count max_count min_id max_id i slot count_ id_ has_meta needed_bits_id needed_bits_count is_empty
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

    if is_empty then
        goto continue
    end

    needed_bits_id = math.bit_length(max_id-min_id)
    needed_bits_count = math.bit_length(max_count-min_count)

    buf:put_uint(needed_bits_id, 4)
    buf:put_uint(needed_bits_count, 4)

    buf:put_uint(min_id, needed_bits_id)
    buf:put_uint(min_count, needed_bits_count)

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
-- VARIABLES needed_bits_id needed_bits_count min_id min_count has_item has_meta slot
-- TO_LOAD inv
do

    if buf:get_bit() then
        return table.rep({}, {id = 0, count = 0}, 40)
    end

    needed_bits_id = buf:get_uint(4)
    needed_bits_count = buf:get_uint(4)

    min_id = buf:get_uint(needed_bits_id)
    min_count = buf:get_uint(needed_bits_count)

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
end--@