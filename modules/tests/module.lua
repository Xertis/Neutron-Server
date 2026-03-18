IS_HEADLESS = false

local total, passed = 0, 0

local function run_test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        print(string.format("%-40s: PASS", name))
        passed = passed + 1
    else
        print(string.format("%-40s: FAIL - %s", name, err))
    end
end

local function create_test_module(is_headless)
    IS_HEADLESS = is_headless

    local m = Module({
        by_identity = {},
        by_username = {},
        by_invid = {}
    })

    local shared = m.shared
    local headless = m.headless
    local single = m.single

    function shared.get_players()
        return "player"
    end

    function shared.by_username.get(username)
        return username
    end

    function shared.by_identity.is_online(id)
        return id == "ID1"
    end

    function headless.mode_check() return "headless" end

    function single.mode_check() return "single" end

    return m:build()
end

run_test("Module initialization", function()
    local my_module = Module({
        get_players = function() return "players_list" end
    })

    assert(type(my_module.shared) == "table", "Shared data missing")
    assert(type(my_module.single) == "table", "Single storage missing")
end)

run_test("Build: Single mode methods", function()
    IS_HEADLESS = false
    local my_module = Module({
        shared_fn = function() return "shared" end
    })

    my_module.single.create_player = function() return "created_single" end

    local built = my_module:build()

    assert(built.shared_fn() == "shared", "Shared function lost")
    assert(built.create_player() == "created_single", "Single function lost")
end)

run_test("Build: Headless isolation", function()
    IS_HEADLESS = true
    local my_module = Module({
        data = "base"
    })

    my_module.headless.mode = "headless_active"
    my_module.single.mode = "single_active"

    local built = my_module:build()

    assert(built.mode == "headless_active", "Wrong side data merged in headless")
    assert(built.data == "base", "Shared data lost in headless")
end)

run_test("Module __index proxy check", function()
    local my_module = Module({
        test_val = 123
    })

    my_module:build()

    assert(my_module.test_val == 123, "Proxy __index failed to find value")
end)

run_test("AutoTable collision prevention", function()
    IS_HEADLESS = false
    local my_module = Module({
        get_players = function() return "ok" end
    })

    local built = my_module:build()

    assert(type(built.get_players) == "function", "Function replaced by table")
    assert(built.get_players() == "ok", "Function return value mismatch")
end)

run_test("Nested structure existence", function()
    local built = create_test_module(false)

    assert(type(built.by_username) == "table", "by_username missing")
    assert(type(built.by_identity) == "table", "by_identity missing")
    assert(type(built.by_username.get) == "function", "Nested function lost")
end)

run_test("Nested function execution & cross-call", function()
    local built = create_test_module(false)

    local player = built.by_username.get("Dev")
    assert(player ~= nil, "Could not find player via nested method")

    assert(built.by_identity.is_online("ID1") == true, "by_identity logic failed")
end)

run_test("Side-specific nested isolation (Single)", function()
    local built = create_test_module(false)
    assert(built.mode_check() == "single", "Should use single method")
end)

run_test("Side-specific nested isolation (Headless)", function()
    local built = create_test_module(true)
    assert(built.mode_check() == "headless", "Should use headless method")
end)

run_test("Deep Table Identity Check", function()
    local built = create_test_module(false)
    local val = built.by_username.non_existent_key
    assert(val == nil, "Nested table is still an AutoTable (unexpected behavior)")
end)

print("---")
print(string.format("Passed %d/%d tests", passed, total))

if passed ~= total then
    error("Test suite failed!")
end
