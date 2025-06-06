local buf = {}
local bincode = {}
local bit = {}

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
    local deg = math.clamp(val, -180, 180)

    buf:put_uint24(math.floor((deg + 180) / 360 * 16777215 + 0.5))
end

-- @degree.read
-- VARIABLES
-- TO_LOAD a
do
    local a = (buf:get_uint24() / 16777215) * 360 - 180
end

-- @boolean.write
-- VARIABLES 
-- TO_SAVE val
do
    val = val and true or false
    buf:put_bit(val)
end

-- @boolean.read
-- VARIABLES 
-- TO_LOAD result
do
    local result = buf:get_bit()
end

-- @var.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_bytes(bincode.encode_varint(val))
end

-- @var.read
-- VARIABLES 
-- TO_LOAD result
do
    local result = bincode.decode_varint(buf)
end

-- @any.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_any(val)
end

-- @any.read
-- VARIABLES 
-- TO_LOAD result
do
    local result = buf:get_any()
end

-- @player_pos.write
-- VARIABLES x y z y_low y_high
-- TO_SAVE val
do
    local x, y, z = unpack(val)
    y = math.clamp(y, 0, 262)

    x = (x - (x - x % 32)) * 1000 + 0.5
    y = math.floor(y * 1000 + 0.5)
    z = (z - (z - z % 32)) * 1000 + 0.5

    local y_low = bit.band(y, 0x1FF)
    local y_high = bit.rshift(y, 9)

    buf:put_uint24(bit.bor(bit.lshift(y_low, 15), x))
    buf:put_uint24(bit.bor(bit.lshift(z, 9), y_high))
end

-- @player_pos.read
-- VARIABLES i1 i2 x y_low y_high y z
-- TO_LOAD result
do
    local i1 = buf:get_uint24()
    local i2 = buf:get_uint24()

    local x = bit.band(i1, 0x7FFF)
    local y_low = bit.rshift(i1, 15)
    local y_high = bit.band(i2, 0x1FF)
    local y = bit.bor(bit.lshift(y_high, 9), y_low)
    local z = bit.rshift(i2, 9)

    local result = {x = x / 1000, y = y / 1000, z = z / 1000}
end

-- @bson.write
-- VARIABLES 
-- TO_SAVE val
do
    bson.encode(buf, val)
end

-- @bson.read
-- VARIABLES 
-- TO_LOAD result
do
    local result = bson.decode(buf)
end

-- @int8.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_byte(val + 127)
end

-- @int8.read
-- VARIABLES 
-- TO_LOAD result
do
    local result = buf:get_byte() - 127
end

-- @uint8.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_byte(val)
end

-- @uint8.read
-- VARIABLES 
-- TO_LOAD result
do
    local result = buf:get_byte()
end

-- @int16.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_sint16(val)
end

-- @int16.read
-- VARIABLES 
-- TO_LOAD result
do
    local result = buf:get_sint16()
end

-- @uint16.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_uint16(val)
end

-- @uint16.read
-- VARIABLES 
-- TO_LOAD result
do
    local result = buf:get_uint16()
end

-- @int32.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_sint32(val)
end

-- @int32.read
-- VARIABLES 
-- TO_LOAD result
do
    local result = buf:get_sint32()
end

-- @uint32.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_uint32(val)
end

-- @uint32.read
-- VARIABLES 
-- TO_LOAD result
do
    local result = buf:get_uint32()
end

-- @int64.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_int64(val)
end

-- @int64.read
-- VARIABLES 
-- TO_LOAD result
do
    local result = buf:get_int64()
end

-- @f32.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_float32(val)
end

-- @f32.read
-- VARIABLES 
-- TO_LOAD result
do
    local result = buf:get_float32()
end

-- @f64.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_float64(val)
end

-- @f64.read
-- VARIABLES 
-- TO_LOAD result
do
    local result = buf:get_float64()
end

-- @string.write
-- VARIABLES 
-- TO_SAVE val
do
    buf:put_string(val)
end

-- @string.read
-- VARIABLES 
-- TO_LOAD result
do
    local result = buf:get_string()
end