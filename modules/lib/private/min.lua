require "std/stdmin"

local lib = {
    protect = {},
    server = {},
    world = {}
}

local function parse_path(path)
    if path == "main.lua" then
        return "server"
    end

    local index = string.find(path, ':')
    if index == nil then
        error("invalid path syntax (':' missing)")
    end
    return string.sub(path, 1, index-1), string.sub(path, index+1, -1)
end

local function get_traceback_length()
    local traceback = debug.traceback()
    local count = 0

    for line in traceback:gmatch("[^\n]+") do
        count = count + 1
    end

    return count-2
end

---PROTECT---

function lib.protect.protect_return(val)
    for call=1, get_traceback_length() do
        local source = debug.getinfo(call).source

        local prefix = parse_path(source)
        if prefix ~= "server" and prefix ~= "core" then
            lib.server.log("Unauthorized Access from " .. source, "W")
            return
        end
    end

    return val
end

function lib.protect.lite_protect_return(val)
    local source = debug.getinfo(3).source

    local prefix = parse_path(source)
    if prefix ~= "server" and prefix ~= "core" then
        lib.server.log("Unauthorized Access from " .. source, "W")
        return
    end

    return val
end

function lib.protect.protect_require()
    for call=1, get_traceback_length() do
        local source = debug.getinfo(call).source

        local prefix = parse_path(source)
        if prefix ~= "server" and prefix ~= "core" then
            lib.server.log("Unauthorized Access from " .. source, "W")
            return true
        end
    end
end

---SERVER---

function lib.server.log(text, type) -- Костыли, ибо debug.log не поддерживает кастомный вывод
    type = type or 'I'
    text = string.first_up(text)

    local source = file.name(debug.getinfo(2).source)
    local out = '[SERVER: ' .. string.left_padding(source, 12) .. '] ' .. text

    local uptime = tostring(math.round(time.uptime(), 8))
    local deltatime = tostring(math.round(time.delta(), 8))

    local timestamp = '[' .. type .. '] ' .. uptime .. ' | ' .. deltatime

    print(timestamp .. string.left_padding(out, #out+33-#timestamp))
end

---WORLD---

function lib.world.preparation_main()
    --Загружаем мир
    local packs = table.copy(CONFIG.game.content_packs)
    app.reconfig_packs(CONFIG.game.content_packs, {})

    if not file.exists("user:worlds/" .. CONFIG.game.main_world .. "/world.json") then
        lib.server.log("Creating a main world")
        local name = CONFIG.game.main_world
        app.new_world(
            CONFIG.game.main_world,
            CONFIG.game.worlds[name].seed,
            CONFIG.game.worlds[name].generator
        )

        app.close_world(true)
    end
end

function lib.world.open_main()
    lib.server.log("Discovery of the main world")
    app.open_world(CONFIG.game.main_world)
end

return lib.protect.lite_protect_return(lib)