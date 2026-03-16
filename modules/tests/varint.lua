local compiler = require "multiplayer/protocol-kernel/compiler"
local bb = require "lib/public/bit_buffer"

local encoder = compiler.load(compiler.compile_encoder({ "varint", "varint" }))
local decoder = compiler.load(compiler.compile_decoder({ "varint", "varint" }))

local total, passed = 0, 0

local function run_test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        print(name .. ": PASS")
        passed = passed + 1
    else
        print(name .. ": FAIL - " .. err)
    end
end

local function test(num)
    local buf = bb:new()
    encoder(buf, num, 255)
    buf:reset()
    local res = decoder(buf)[1]
    assert(res == num, string.format("Ожидали: %s; Получили: %s", num, res))
end

run_test("2^31 encode-decode", function()
    test((2 ^ 31) - 1)
    test(-(2 ^ 31))
end)

run_test("-100000..100000 encode-decode", function()
    for i = -100000, 100000 do
        test(i)
    end
end)

print(string.format("Passed %d/%d tests", passed, total))
if passed ~= total then error() end
