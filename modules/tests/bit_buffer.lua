local bb = import "lib/io/bit_buffer"

local total, passed = 0, 0

local function run_test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        print(name .. ": PASS")
        passed = passed + 1
    else
        print(name .. ": FAIL - " .. tostring(err))
    end
end

local function new_be() return bb:new(nil, "BE") end
local function new_le() return bb:new(nil, "LE") end

local start = os.clock()

-- ────────────────────────────────────────────
-- BITS: crossing byte boundaries
-- ────────────────────────────────────────────

run_test("bits: 9 бит через границу байта", function()
    local buf = new_be()
    -- записываем 9 единичных бит → 0xFF + 1 бит
    for i = 1, 9 do buf:put_bit(true) end
    buf:flush()
    buf:reset()
    for i = 1, 9 do
        local b = buf:get_bit()
        assert(b == true, "бит #" .. i .. " должен быть true")
    end
end)

run_test("bits: чередование 0/1 через 3 байта", function()
    local buf = new_be()
    local pattern = {}
    for i = 1, 24 do
        local v = (i % 2 == 0)
        pattern[i] = v
        buf:put_bit(v)
    end
    buf:flush()
    buf:reset()
    for i = 1, 24 do
        local got = buf:get_bit()
        assert(got == pattern[i], "бит #" .. i .. " не совпадает")
    end
end)

run_test("bits: запись нечётного числа бит (5), затем байт", function()
    local buf = new_be()
    buf:put_uint(0x1F, 5) -- 11111
    buf:put_byte(0xAB)
    buf:flush()
    buf:reset()
    local u5 = buf:get_uint(5)
    assert(u5 == 0x1F, string.format("5 бит: ожидали 0x1F, получили 0x%X", u5))
    local b = buf:get_byte()
    assert(b == 0xAB, string.format("байт: ожидали 0xAB, получили 0x%X", b))
end)

run_test("bits: get_uint(1) для одного бита", function()
    local buf = new_be()
    buf:put_uint(1, 1)
    buf:put_uint(0, 1)
    buf:flush()
    buf:reset()
    assert(buf:get_uint(1) == 1, "первый бит должен быть 1")
    assert(buf:get_uint(1) == 0, "второй бит должен быть 0")
end)

run_test("put_uint/get_uint: произвольные ширины 1–31", function()
    for w = 1, 31 do
        local max_val = math.floor(2 ^ w - 1)
        local vals = { 0, 1, math.floor(max_val / 2), max_val }
        for _, v in ipairs(vals) do
            local buf = new_be()
            buf:put_uint(v, w)
            buf:flush()
            buf:reset()
            local got = buf:get_uint(w)
            assert(got == v,
                string.format("width=%d val=%d: ожидали %d, получили %d", w, v, v, got))
        end
    end
end)

-- ────────────────────────────────────────────
-- BYTE-ALIGNED + BIT-OFFSET INTERLEAVE
-- ────────────────────────────────────────────

run_test("put_uint16 со смещением 1 бит", function()
    local vals = { 0, 1, 255, 256, 32767, 65535 }
    for _, v in ipairs(vals) do
        local buf = new_be()
        buf:put_bit(true) -- offset=1
        buf:put_uint(v, 16)
        buf:flush()
        buf:reset()
        assert(buf:get_bit() == true, "sentinel bit")
        local got = buf:get_uint(16)
        assert(got == v, string.format("uint16 со смещением 1: ожидали %d, получили %d", v, got))
    end
end)

run_test("put_uint32 со смещением 3 бита", function()
    local vals = { 0, 1, 0xFFFF, 0x10000, 0x7FFFFFFF, 0xFFFFFFFF }
    for _, v in ipairs(vals) do
        local buf = new_be()
        buf:put_uint(5, 3) -- 3 бита = 0b101
        buf:put_uint(v, 32)
        buf:flush()
        buf:reset()
        local pre = buf:get_uint(3)
        assert(pre == 5, "prefix bits")
        local got = buf:get_uint(32)
        assert(got == v, string.format("uint32 со смещением 3: ожидали %d, получили %d", v, got))
    end
end)

run_test("uint32 смещение 7 бит (максимально неудобное)", function()
    local v = 0xDEADBEEF % (2 ^ 32) -- в пределах uint32
    local buf = new_be()
    buf:put_uint(1, 7)
    buf:put_uint(v, 32)
    buf:flush()
    buf:reset()
    buf:get_uint(7)
    local got = buf:get_uint(32)
    assert(got == v, string.format("7-bit offset uint32: ожидали %d, получили %d", v, got))
end)

-- ────────────────────────────────────────────
-- UINT24
-- ────────────────────────────────────────────

run_test("put_uint24/get_uint24: границы", function()
    local vals = { 0, 1, 255, 256, 65535, 65536, 0xFFFFFF }
    for _, v in ipairs(vals) do
        for _, buf in ipairs({ new_be(), new_le() }) do
            buf:put_uint24(v)
            buf:reset()
            local got = buf:get_uint24()
            assert(got == v, string.format("uint24 %d: ожидали %d, получили %d", v, v, got))
        end
    end
end)

run_test("put_uint24 со смещением 4 бита", function()
    local v = 0xABCDEF
    local buf = new_be()
    buf:put_uint(0xF, 4)
    buf:put_uint24(v)
    buf:flush()
    buf:reset()
    assert(buf:get_uint(4) == 0xF, "prefix")
    local got = buf:get_uint24()
    assert(got == v, string.format("uint24 с офсетом 4: ожидали %d, получили %d", v, got))
end)

-- ────────────────────────────────────────────
-- INT SIGNED BOUNDARIES
-- ────────────────────────────────────────────

run_test("put_int8/get_int8: -128 и 127", function()
    for _, v in ipairs({ -128, -1, 0, 1, 127 }) do
        local buf = new_be()
        buf:put_int8(v)
        buf:reset()
        local got = buf:get_int8()
        assert(got == v, string.format("int8 %d", v))
    end
end)

run_test("put_int32/get_int32 в LE и BE", function()
    local vals = { 0, 1, -1, 2147483647, -2147483648, 0x1234567 }
    for _, v in ipairs(vals) do
        for _, buf in ipairs({ new_be(), new_le() }) do
            buf:put_int32(v)
            buf:reset()
            local got = buf:get_int32()
            assert(got == v, string.format("int32 %d endian", v))
        end
    end
end)

-- ────────────────────────────────────────────
-- FLOAT16 EDGE CASES
-- ────────────────────────────────────────────

run_test("float16: +inf / -inf", function()
    for _, v in ipairs({ math.huge, -math.huge }) do
        local buf = new_be()
        buf:put_float16(v)
        buf:reset()
        local got = buf:get_float16()
        assert(got == v, string.format("float16 inf: ожидали %g, получили %g", v, got))
    end
end)

run_test("float16: -0.0 и +0.0", function()
    for _, v in ipairs({ 0.0, -0.0 }) do
        local buf = new_be()
        buf:put_float16(v)
        buf:reset()
        local got = buf:get_float16()
        assert(got == 0.0, string.format("float16 zero: получили %g", got))
    end
end)

run_test("float16: мелкие субнормальные значения", function()
    -- наименьшее субнормальное float16 ≈ 5.96e-8
    local v = 5.96e-8
    local buf = new_be()
    buf:put_float16(v)
    buf:reset()
    local got = buf:get_float16()
    -- может быть 0 или очень близко
    assert(got >= 0, "суб-нормаль должна быть >= 0")
end)

run_test("float16 LE vs BE: разные порядки байт", function()
    local v = 1.5
    local be_buf = new_be()
    local le_buf = new_le()
    be_buf:put_float16(v)
    le_buf:put_float16(v)
    -- байты должны различаться
    local be_b0 = be_buf.bytes[1]
    local le_b0 = le_buf.bytes[1]
    assert(be_b0 ~= le_b0, "BE и LE float16 должны иметь разные первые байты")
    -- но оба должны корректно читаться
    be_buf:reset()
    le_buf:reset()
    local be_got = be_buf:get_float16()
    local le_got = le_buf:get_float16()
    assert(math.abs(be_got - v) < 0.01, "BE float16 round-trip")
    assert(math.abs(le_got - v) < 0.01, "LE float16 round-trip")
end)

-- ────────────────────────────────────────────
-- NORM8
-- ────────────────────────────────────────────

run_test("put_norm8/get_norm8: граничные значения", function()
    local cases = { -1.0, -0.5, 0.0, 0.5, 1.0 }
    for _, v in ipairs(cases) do
        local buf = new_be()
        buf:put_norm8(v)
        buf:reset()
        local got = buf:get_norm8()
        assert(math.abs(got - v) < 0.01,
            string.format("norm8 %g: ожидали ~%g, получили %g", v, v, got))
    end
end)

-- ────────────────────────────────────────────
-- STRING EDGE CASES
-- ────────────────────────────────────────────

run_test("put_string/get_string: несколько строк подряд", function()
    local strs = { "hello", "world", "", "тест", "abc123" }
    local buf = new_be()
    for _, s in ipairs(strs) do buf:put_string(s) end
    buf:reset()
    for _, s in ipairs(strs) do
        local got = buf:get_string()
        assert(got == s, string.format("строка: ожидали '%s', получили '%s'", s, got))
    end
end)

run_test("put_string/get_string: строка длиной 200 символов", function()
    local s = string.rep("x", 200)
    local buf = new_be()
    buf:put_string(s)
    buf:reset()
    local got = buf:get_string()
    assert(got == s, "длинная строка не совпадает")
end)

-- ────────────────────────────────────────────
-- SEQUENTIAL MIXED WRITES
-- ────────────────────────────────────────────

run_test("смешанная запись: биты + uint + float + строка", function()
    local buf = new_be()
    buf:put_bit(true)
    buf:put_uint(7, 3)
    buf:put_uint16(1000)
    buf:put_float32(3.14)
    buf:put_string("ok")
    buf:put_bit(false)
    buf:flush()
    buf:reset()

    assert(buf:get_bit() == true, "бит 1")
    assert(buf:get_uint(3) == 7, "uint(3)")
    assert(buf:get_uint16() == 1000, "uint16")
    local f = buf:get_float32()
    assert(math.abs(f - 3.14) < 1e-5, "float32")
    assert(buf:get_string() == "ok", "string")
    assert(buf:get_bit() == false, "бит 2")
end)

-- ────────────────────────────────────────────
-- put_any / get_any EDGE CASES
-- ────────────────────────────────────────────

run_test("put_any/get_any: граница uint8/uint16 (255 и 256)", function()
    for _, v in ipairs({ 255, 256 }) do
        local buf = new_be()
        buf:put_any(v)
        buf:reset()
        local got = buf:get_any()
        assert(got == v, string.format("put_any boundary %d", v))
    end
end)

run_test("put_any/get_any: граница uint16/uint24 (65535 и 65536)", function()
    for _, v in ipairs({ 65535, 65536 }) do
        local buf = new_be()
        buf:put_any(v)
        buf:reset()
        local got = buf:get_any()
        assert(got == v, string.format("put_any boundary %d", v))
    end
end)

run_test("put_any/get_any: граница uint24/uint32 (16777215 и 16777216)", function()
    for _, v in ipairs({ 16777215, 16777216 }) do
        local buf = new_be()
        buf:put_any(v)
        buf:reset()
        local got = buf:get_any()
        assert(got == v, string.format("put_any boundary %d", v))
    end
end)

run_test("put_any/get_any: nil", function()
    local buf = new_be()
    buf:put_any(nil)
    buf:reset()
    local got = buf:get_any()
    assert(got == nil, "put_any(nil) должен вернуть nil")
end)

run_test("put_any/get_any: несколько значений подряд разных типов", function()
    local items = { true, false, 0, 255, 256, 65536, -1, -32769, 1.5, "hi", nil }
    local buf = new_be()
    for _, v in ipairs(items) do buf:put_any(v) end
    buf:reset()
    for i, expected in ipairs(items) do
        local got = buf:get_any()
        assert(got == expected,
            string.format("put_any seq #%d: ожидали %s, получили %s",
                i, tostring(expected), tostring(got)))
    end
end)

-- ────────────────────────────────────────────
-- POSITION MANIPULATION
-- ────────────────────────────────────────────

run_test("set_position / повторное чтение", function()
    local buf = new_be()
    buf:put_byte(0x42)
    buf:put_byte(0xFF)
    buf:reset()
    local a = buf:get_byte()
    buf:set_position(1) -- перемотка на начало
    local b = buf:get_byte()
    assert(a == b and a == 0x42, "повторное чтение через set_position")
end)

run_test("move_position: пропуск байта", function()
    local buf = new_be()
    buf:put_byte(0x11)
    buf:put_byte(0x22)
    buf:put_byte(0x33)
    buf:reset()
    buf:move_position(8) -- пропускаем первый байт
    local got = buf:get_byte()
    assert(got == 0x22, string.format("move_position: ожидали 0x22, получили 0x%X", got))
end)

run_test("size() после записи нескольких байт", function()
    local buf = new_be()
    buf:put_byte(1)
    buf:put_byte(2)
    buf:put_byte(3)
    -- pos == 25 → size = floor(25/8) = 3
    assert(buf:size() == 3, "size() должен быть 3")
end)

-- ────────────────────────────────────────────
-- FLUSH IDEMPOTENCY
-- ────────────────────────────────────────────

run_test("flush() после выровненной записи не добавляет лишний байт", function()
    local buf = new_be()
    buf:put_byte(0xAA)
    buf:put_byte(0xBB) -- pos == 17, выравнено
    local sz_before = buf:size()
    buf:flush()
    assert(buf:size() == sz_before, "flush() на выравненной границе не должен менять размер")
end)

run_test("flush() сохраняет неполный байт", function()
    local buf = new_be()
    buf:put_uint(0x3, 2) -- два бита, не флашим
    buf:flush()
    buf:reset()
    local got = buf:get_uint(2)
    assert(got == 0x3, string.format("после flush 2 бита: ожидали 3, получили %d", got))
end)

-- ────────────────────────────────────────────
-- ENDIANNESS: LE vs BE байтовый порядок
-- ────────────────────────────────────────────

run_test("LE vs BE uint16: байты должны быть зеркальными", function()
    local v = 0x1234
    local be = new_be()
    local le = new_le()
    be:put_uint16(v)
    le:put_uint16(v)
    -- BE: [0x12, 0x34], LE: [0x34, 0x12]
    assert(be.bytes[1] == 0x12 and be.bytes[2] == 0x34,
        string.format("BE bytes: %02X %02X", be.bytes[1], be.bytes[2]))
    assert(le.bytes[1] == 0x34 and le.bytes[2] == 0x12,
        string.format("LE bytes: %02X %02X", le.bytes[1], le.bytes[2]))
end)

run_test("LE vs BE uint32: оба корректно читаются назад", function()
    local v = 0xABCD
    for _, buf in ipairs({ new_be(), new_le() }) do
        buf:put_uint32(v)
        buf:reset()
        local got = buf:get_uint32()
        assert(got == v, string.format("uint32 endian round-trip: %d", v))
    end
end)

-- ────────────────────────────────────────────
-- STRESS: большой буфер
-- ────────────────────────────────────────────

run_test("стресс: 1000 uint16 round-trip", function()
    local buf = new_be()
    local N = 1000
    for i = 1, N do buf:put_uint16(i % 65536) end
    buf:reset()
    for i = 1, N do
        local got = buf:get_uint16()
        local expected = i % 65536
        assert(got == expected, string.format("uint16 #%d: ожидали %d, получили %d", i, expected, got))
    end
end)

run_test("стресс: 500 чередующихся бит и байт", function()
    local buf = new_be()
    local vals = {}
    for i = 1, 500 do
        if i % 3 == 0 then
            local v = i % 256
            buf:put_byte(v)
            vals[i] = { "byte", v }
        else
            local b = (i % 2 == 0)
            buf:put_bit(b)
            vals[i] = { "bit", b }
        end
    end
    buf:flush()
    buf:reset()
    for i = 1, 500 do
        local kind, expected = vals[i][1], vals[i][2]
        if kind == "byte" then
            local got = buf:get_byte()
            assert(got == expected, string.format("byte #%d", i))
        else
            local got = buf:get_bit()
            assert(got == expected, string.format("bit #%d", i))
        end
    end
end)

-- ────────────────────────────────────────────
-- INIT FROM EXISTING BYTES
-- ────────────────────────────────────────────

run_test("создание буфера из таблицы байт", function()
    local buf = bb:new({ 0x41, 0x42, 0xFF }) -- 'A', 'B', 255
    local a = buf:get_byte()
    local b_val = buf:get_byte()
    local c = buf:get_byte()
    assert(a == 0x41, "первый байт 0x41")
    assert(b_val == 0x42, "второй байт 0x42")
    assert(c == 0xFF, "третий байт 0xFF")
end)

run_test("set_bytes и перечитывание", function()
    local buf = new_be()
    buf:set_bytes({ 0xDE, 0xAD })
    buf:reset()
    assert(buf:get_byte() == 0xDE, "0xDE")
    assert(buf:get_byte() == 0xAD, "0xAD")
end)

-- ────────────────────────────────────────────

print(string.format("\nPassed %d/%d tests in %.3f sec",
    passed, total, os.clock() - start))
if passed ~= total then error() end
