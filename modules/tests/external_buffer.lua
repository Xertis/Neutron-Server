local receiver = require "server:multiplayer/protocol-kernel/receiver"

local buffer = receiver.create_buffer()
local function roundtrip()
  receiver.empty(buffer)
  local bytes = {}
  for i=1, 255 do
    bytes[i] = i
  end
  receiver.__apppend(buffer, bytes)
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

run_test("get", function()
  roundtrip()
  assert(receiver.get(buffer, 1) == 1, "get(1) должно быть 1")
  assert(receiver.get(buffer, 36) == 36, "get(36) должно быть 36")
  assert(receiver.get(buffer, 255) == 255, "get(255) должно быть 255")
end)

run_test("clear", function()
  roundtrip()
  receiver.clear(buffer, 15)
  assert(receiver.get(buffer, 1) == 16, "get(1) должно быть 16")
  roundtrip()
  receiver.clear(buffer, 255)
  assert(receiver.get(buffer, 1) == nil, "get(1) должен быть nil")
  roundtrip()
  receiver.clear(buffer, 0)
  assert(receiver.get(buffer, 1) == 1, "get(1) должен быть 1")
  roundtrip()
  receiver.clear(buffer, 40)
  assert(receiver.get(buffer, 1) == 41, "get(1) должен быть 41")
end)

run_test("len", function()
  roundtrip()
  receiver.clear(buffer, 255)
  assert(receiver.len(buffer) == 0, "len() должен быть 0")
  roundtrip()
  receiver.clear(buffer, 0)
  assert(receiver.len(buffer) == 255, "len() должен быть 255")
  roundtrip()
  receiver.clear(buffer, 10)
  assert(receiver.len(buffer) == 245, "len() должен быть 245")
end)

print(string.format("Passed %d/%d tests", passed, total))
if passed ~= total then error() end
