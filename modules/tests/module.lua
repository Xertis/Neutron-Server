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

local HEADLESS = false

vc = {}

function vc.is_headless()
    return HEADLESS
end

local function create_test_module(is_headless)
    HEADLESS = is_headless

    local m = Module({
        by_identity = {},
        by_username = {},
        by_invid = {}
    })

    function m.shared.get_players()
        return "player"
    end

    function m.shared.by_username.get(username)
        return username
    end

    function m.shared.by_identity.is_online(id)
        return id == "ID1"
    end

    function m.server.mode_check()
        return "server"
    end

    function m.client.mode_check()
        return "client"
    end

    return m:build()
end

run_test("Module initialization", function()
    local m = Module({
        get_players = function()
            return "players"
        end
    })

    assert(type(m.shared) == "table")
    assert(type(m.client) == "table")
    assert(type(m.server) == "table")
end)

run_test("Build: Client mode methods", function()
    HEADLESS = false

    local m = Module({
        shared_fn = function()
            return "shared"
        end
    })

    function m.client.create_player()
        return "created_client"
    end

    local built = m:build()

    assert(built.shared_fn() == "shared")
    assert(built.create_player() == "created_client")
end)

run_test("Build: Server isolation", function()
    HEADLESS = true

    local m = Module({
        data = "base"
    })

    m.server.mode = "server_active"
    m.client.mode = "client_active"

    local built = m:build()

    assert(built.mode == "server_active")
    assert(built.data == "base")
end)

run_test("Module __index proxy check", function()
    local m = Module({
        test_val = 123
    })

    m:build()

    assert(m.test_val == 123)
end)

run_test("AutoTable collision prevention", function()
    local m = Module({
        get_players = function()
            return "ok"
        end
    })

    local built = m:build()

    assert(type(built.get_players) == "function")
    assert(built.get_players() == "ok")
end)

run_test("Large nesting AutoTable", function()
    HEADLESS = true

    local m = Module()

    function m.server.a.b.c.d()
        return "ok"
    end

    local built = m:build()

    assert(built.a.b.c.d() == "ok")
end)

run_test("Nested structure existence", function()
    local built = create_test_module(false)

    assert(type(built.by_username) == "table")
    assert(type(built.by_identity) == "table")
    assert(type(built.by_username.get) == "function")
end)

run_test("Nested function execution", function()
    local built = create_test_module(false)

    assert(built.by_username.get("Dev") == "Dev")
    assert(built.by_identity.is_online("ID1") == true)
    assert(built.by_identity.is_online("ID2") == false)
end)

run_test("Side-specific method (Client)", function()
    local built = create_test_module(false)

    assert(built.mode_check() == "client")
end)

run_test("Side-specific method (Server)", function()
    local built = create_test_module(true)

    assert(built.mode_check() == "server")
end)

run_test("Deep Table Identity Check", function()
    local built = create_test_module(false)

    assert(built.by_username.non_existent_key == nil)
end)

print("---")
print(string.format("Passed %d/%d tests", passed, total))

if passed ~= total then
    error("Test suite failed!")
end
