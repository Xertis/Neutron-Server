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

local function new_le() return bb:new(nil, "BE") end

local function roundtrip(write_fn, read_fn, values, fmt)
    for _, v in ipairs(values) do
        local buf = new_le()
        write_fn(buf, v)
        buf:flush()
        buf:reset()
        local got = read_fn(buf)
        assert(got == v, string.format(fmt or "Ожидали %s; Получили %s", tostring(v), tostring(got)))
    end
end

run_test("put_bit/get_bit: true/false", function()
    for _, b in ipairs({ true, false }) do
        local buf = new_le()
        buf:put_bit(b)
        buf:flush()
        buf:reset()
        local got = buf:get_bit()
        assert(got == b,
            string.format("Ожидали %s; Получили %s", tostring(b), tostring(got)))
    end
end)

run_test("put_byte/get_byte: 0, 127, 255", function()
    roundtrip(
        function(buf, v) buf:put_byte(v) end,
        function(buf) return buf:get_byte() end,
        { 0, 1, 127, 254, 255 }
    )
end)

run_test("put_uint16/get_uint16: границы", function()
    roundtrip(
        function(buf, v) buf:put_uint16(v) end,
        function(buf) return buf:get_uint16() end,
        { 0, 1, 255, 256, 32767, 65535 }
    )
end)

run_test("put_uint32/get_uint32: границы", function()
    roundtrip(
        function(buf, v) buf:put_uint32(v) end,
        function(buf) return buf:get_uint32() end,
        { 0, 1, 65535, 65536, 2147483647, 4294967295 }
    )
end)

run_test("put_int8/get_int8: -128..127", function()
    roundtrip(
        function(buf, v) buf:put_int8(v) end,
        function(buf) return buf:get_int8() end,
        { 0, 1, -1, 127, -128, 100, -100 }
    )
end)

run_test("put_int16/get_int16: границы", function()
    roundtrip(
        function(buf, v) buf:put_int16(v) end,
        function(buf) return buf:get_int16() end,
        { 0, 1, -1, 32767, -32768, 1000, -1000 }
    )
end)

run_test("put_int32/get_int32: границы", function()
    roundtrip(
        function(buf, v) buf:put_int32(v) end,
        function(buf) return buf:get_int32() end,
        { 0, 1, -1, 2147483647, -2147483648, 100000, -100000 }
    )
end)

run_test("put_int64/get_int64: границы", function()
    roundtrip(
        function(buf, v) buf:put_int64(v) end,
        function(buf) return buf:get_int64() end,
        { 0, 1, 65535, 65536, 2147483647, 4294967295, -1, -2147483648, 2 ^ 40, -2 ^ 40 }
    )
end)

run_test("put_float16/get_float16: базовые значения", function()
    local cases = { 0.0, 1.0, -1.0, 3.14, -3.14, 5, 10 }
    for _, v in ipairs(cases) do
        local buf = new_le()
        buf:put_float16(v)
        buf:reset()
        local got = buf:get_float16()
        local rel_err = math.abs(got - v) / (math.abs(v) + 1e-10)
        assert(rel_err < 1e-2,
            string.format("float16: Ожидали %g; Получили %g", v, got))
    end
end)

run_test("put_float32/get_float32: базовые значения", function()
    local cases = { 0.0, 1.0, -1.0, 3.14, -3.14, 1e10, -1e10 }
    for _, v in ipairs(cases) do
        local buf = new_le()
        buf:put_float32(v)
        buf:reset()
        local got = buf:get_float32()
        local rel_err = math.abs(got - v) / (math.abs(v) + 1e-10)
        assert(rel_err < 1e-5,
            string.format("float32: Ожидали %g; Получили %g", v, got))
    end
end)

run_test("put_float64/get_float64: базовые значения", function()
    local cases = { 0.0, 1.0, -1.0, math.pi, -math.pi, 1e100, -1e100 }
    for _, v in ipairs(cases) do
        local buf = new_le()
        buf:put_float64(v)
        buf:reset()
        local got = buf:get_float64()
        local rel_err = math.abs(got - v) / (math.abs(v) + 1e-10)
        assert(rel_err < 1e-10,
            string.format("float64: Ожидали %g; Получили %g", v, got))
    end
end)

run_test("put_string/get_string: короткая строка", function()
    local buf = new_le()
    buf:put_string("hello")
    buf:reset()
    local got = buf:get_string()
    assert(got == "hello",
        string.format("Ожидали 'hello'; Получили '%s'", tostring(got)))
end)

run_test("put_string/get_string: пустая строка", function()
    local buf = new_le()
    buf:put_string("")
    buf:reset()
    local got = buf:get_string()
    assert(got == "",
        string.format("Ожидали ''; Получили '%s'", tostring(got)))
end)

run_test("put_string/get_string: Unicode", function()
    local buf = new_le()
    buf:put_string("Нейтрон")
    buf:reset()
    local got = buf:get_string()
    assert(got == "Нейтрон",
        string.format("Ожидали 'Нейтрон'; Получили '%s'", tostring(got)))
end)

run_test("put_norm16/get_norm16: 0.0", function()
    local buf = new_le()
    buf:put_norm16(0.0)
    buf:reset()
    local got = buf:get_norm16()
    assert(math.abs(got - 0.0) < 0.001,
        string.format("Ожидали ~0.0; Получили %g", got))
end)

run_test("put_norm16/get_norm16: 1.0", function()
    local buf = new_le()
    buf:put_norm16(1.0)
    buf:reset()
    local got = buf:get_norm16()
    assert(math.abs(got - 1.0) < 0.001,
        string.format("Ожидали ~1.0; Получили %g", got))
end)

run_test("put_norm16/get_norm16: -1.0", function()
    local buf = new_le()
    buf:put_norm16(-1.0)
    buf:reset()
    local got = buf:get_norm16()
    assert(math.abs(got - (-1.0)) < 0.001,
        string.format("Ожидали ~-1.0; Получили %g", got))
end)

run_test("put_any/get_any: отрицательный int16", function()
    local cases = { -1, -100, -1000, -32768 }
    for _, v in ipairs(cases) do
        local buf = new_le()
        buf:put_any(v)
        buf:reset()
        local got = buf:get_any()
        assert(got == v,
            string.format("int16: Ожидали %d; Получили %s", v, tostring(got)))
    end
end)

run_test("put_any/get_any: отрицательный int32", function()
    local cases = { -32769, -100000, -2147483648 }
    for _, v in ipairs(cases) do
        local buf = new_le()
        buf:put_any(v)
        buf:reset()
        local got = buf:get_any()
        assert(got == v,
            string.format("int32: Ожидали %d; Получили %s", v, tostring(got)))
    end
end)

run_test("put_any/get_any: bool, uint8, uint16, uint32, float64", function()
    local cases = {
        { true,  true },
        { false, false },
        { 0,     0 },
        { 200,   200 },
        { 1000,  1000 },
        { 70000, 70000 },
        { 1.5,   1.5 },
    }
    for _, pair in ipairs(cases) do
        local v, expected = pair[1], pair[2]
        local buf = new_le()
        buf:put_any(v)
        buf:reset()
        local got = buf:get_any()
        assert(got == expected,
            string.format("put_any: Ожидали %s; Получили %s",
                tostring(expected), tostring(got)))
    end
end)

run_test("next(): выравнивание в середине байта", function()
    local buf = new_le()
    buf:put_byte(0xAB)
    buf:put_byte(0xCD)
    buf:reset()
    buf:get_uint(3)
    buf:next()
    local got = buf:get_byte()
    assert(got == 0xCD,
        string.format("next() после 3 бит: Ожидали 0xCD (205); Получили %d", got))
end)

run_test("next(): выравнивание после полного байта", function()
    local buf = new_le()
    buf:put_byte(0x11)
    buf:put_byte(0x22)
    buf:put_byte(0x33)
    buf:reset()
    buf:get_byte()
    buf:next()
    local got = buf:get_byte()
    assert(got == 0x22,
        string.format("next() на границе байта: Ожидали 0x22 (34); Получили %d", got))
end)

print(string.format("Passed %d/%d tests", passed, total))
if passed ~= total then error() end
