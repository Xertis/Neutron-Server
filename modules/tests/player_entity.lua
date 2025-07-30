local compiler = require "server:multiplayer/protocol-kernel/compiler"
local bb = require "lib/public/bit_buffer"

local function deep_approx_equals(a, b, epsilon)
    if type(a) ~= type(b) then
        return false
    end

    if type(a) == "table" then
        local visited = {}
        for k, v in pairs(a) do
            visited[k] = true
            if not deep_approx_equals(v, b[k], epsilon) then
                return false
            end
        end
        for k, _ in pairs(b) do
            if not visited[k] then
                return false
            end
        end
        return true
    elseif type(a) == "number" then
        return math.abs(a - b) <= (epsilon or 1e-5)
    else
        return a == b
    end
end

local encoder = compiler.load(compiler.compile_encoder({"PlayerEntity"}))
local decoder = compiler.load(compiler.compile_decoder({"PlayerEntity"}))

local function roundtrip(tbl)
    local buf = bb:new()
    encoder(buf, tbl)
    buf:flush()
    buf:reset()
    return decoder(buf)[1]
end

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

for i=1, 25 do
    run_test("PlayerEntity random test", function()
        local player = { compressed = false }
        if math.random() > 0.5 then
            player.pos = {
                x = math.random() * 200 - 100,
                y = math.random() * 100,
                z = math.random() * 200 - 100,
            }
        end
        if math.random() > 0.5 then
            player.rot = {
                yaw = math.random() * 360 - 180,
                pitch = math.random() * 360 - 180,
            }
        end
        if math.random() > 0.7 then
            player.cheats = {
                noclip = math.random() > 0.5,
                flight = math.random() > 0.5,
            }
        end

        local decoded = roundtrip(player)
        assert(deep_approx_equals(decoded, player, 0.01), "Decoded data does not match original")
    end)

    math.randomseed(os.clock() + i)
end

print(string.format("Passed %d/%d tests", passed, total))
if passed ~= total then error() end