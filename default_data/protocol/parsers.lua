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
-- VARIABLES x y z y_low y_high
-- TO_SAVE val
do
    x, y, z = unpack(val)
    y = math.clamp(y, 0, 262)

    x = (x - (x - x % 32)) * 1000 + 0.5
    y = math.floor(y * 1000 + 0.5)
    z = (z - (z - z % 32)) * 1000 + 0.5

    y_low = bit.band(y, 0x1FF)
    y_high = bit.rshift(y, 9)

    buf:put_uint24(bit.bor(bit.lshift(y_low, 15), x))
    buf:put_uint24(bit.bor(bit.lshift(z, 9), y_high))
end--@

-- @player_pos.read
-- VARIABLES i ii xx y_low y_high yy zz
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
    buf:put_bytes(data[3])
end--@

-- @Chunk.read
-- VARIABLES
-- TO_LOAD chunk
do
    chunk = {
        buf:put_sint16(),
        buf:put_sint16(),
        buf:put_bytes(),
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