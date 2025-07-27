local bb = require "lib/public/bit_buffer"
local edd = require "server:lib/private/files/edd"

local function roundtrip(tbl)
  local buf = bb:new()
  edd.encode(buf, tbl)
  buf:flush()
  buf:reset()
  return edd.decode(buf)
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

run_test("empty structure", function()
  local decoded = roundtrip({})
  assert(decoded.standart_fields == nil, "standart_fields должно быть nil")
  assert(decoded.custom_fields == nil, "custom_fields должно быть nil")
  assert(decoded.textures == nil, "textures должно быть nil")
  assert(decoded.eddels == nil, "eddels должно быть nil")
  assert(decoded.components == nil, "components должно быть nil")
end)

run_test("numeric fields in custom_fields", function()
  local dirty = { custom_fields = {
    small = 42,
    large = 70000,
    neg_small = -10,
    neg_large = -70000
  }}
  local decoded = roundtrip(dirty)
  assert(table.deep_equals(decoded.custom_fields, dirty.custom_fields), "числовые поля не совпадают")
end)

run_test("string and boolean in custom_fields", function()
  local dirty = { custom_fields = {
    greeting = "hello",
    flag_true = true,
    flag_false = false
  }}
  local decoded = roundtrip(dirty)
  assert(table.deep_equals(decoded.custom_fields, dirty.custom_fields), "строки/булевы значения не совпадают")
end)

run_test("nested tables in custom_fields", function()
  local dirty = { custom_fields = {
    numbers = {1,2,3},
    nested = { a = "x", b = false, c = 5 }
  }}
  local decoded = roundtrip(dirty)
  assert(table.deep_equals(decoded.custom_fields, dirty.custom_fields), "вложенные таблицы не совпадают")
end)

run_test("standart_fields transforms", function()
  local dirty = { standart_fields = {
    tsf_pos = {1.0, 2.0, 3.0},
    tsf_size = {4.0, 5.0, 6.0},
    body_size = {7.0, 8.0, 9.0}
  }}
  local decoded = roundtrip(dirty)
  assert(table.deep_equals(decoded.standart_fields.tsf_pos, dirty.standart_fields.tsf_pos), "tsf_pos не совпадает")
  assert(table.deep_equals(decoded.standart_fields.tsf_size, dirty.standart_fields.tsf_size), "tsf_size не совпадает")
  assert(table.deep_equals(decoded.standart_fields.body_size, dirty.standart_fields.body_size), "body_size не совпадает")
end)

run_test("textures, models and components", function()
  local dirty = {
    textures = { albedo = "tex_a.png", normal = "tex_n.png" },
    models   = { ["0"] = "model1.obj", [1] = "model2.obj" },
    components = { compA = true, compB = false }
  }

  local dirty2 = {
    textures = { albedo = "tex_a.png", normal = "tex_n.png" },
    models   = { [0] = "model1.obj", [1] = "model2.obj" },
    components = { compA = true, compB = false }
  }

  local decoded = roundtrip(dirty)
  assert(table.deep_equals(decoded.textures, dirty.textures), "textures не совпадают")
  assert(table.deep_equals(decoded.models, dirty2.models), "models не совпадают")
  assert(table.deep_equals(decoded.components, dirty.components), "components не совпадают")
end)

print(string.format("Passed %d/%d tests", passed, total))
if passed ~= total then error() end
