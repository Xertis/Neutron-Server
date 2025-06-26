app.config_packs({"server"})
app.load_content()
require "server:std/stdboot"

LAUNCH_ATTEMPTS = 1

local function tests()
    -- Тест парсеров пакетов

    -- Тест инвентаря
    local compiler = require "server:multiplayer/protocol-kernel/compiler"
    local bit_buffer = require "server:lib/public/bit_buffer"

    local encoder = compiler.compile_encoder({"Inventory"})
    local decoder = compiler.compile_decoder({"Inventory"})

    local encoder_compil = compiler.load(encoder)
    local decoder_compil = compiler.load(decoder)

    local Inventory = {}
    local inv = {}
    for i=1, 40 do
        local id = math.random(0, 1000)
        local count = math.random(0, 1000)
        local meta = {abc = 200}

        if id == 0 then
            Inventory[i] = {id = 0, count = 0}
        else
            Inventory[i] = {id = id, count = count, meta = meta}
        end
    end

    local status, res = pcall(function ()
        local buf = bit_buffer:new()
        encoder_compil(buf, Inventory)

        buf:flush()
        buf:reset()

        inv = decoder_compil(buf)[1]

        return table.deep_equals(Inventory, inv)
    end)

    if not status or not res then
        print(json.tostring(Inventory))
        print("=======================")
        print(json.tostring(inv))
        error("Error: " .. tostring(res))
    else
        logger.log("Inventory packet test passed", "T")
    end


    -- Конец тестов
    logger.log("All tests passed", "T")
end

local function main()
    app.config_packs({"server"})
    app.load_content()

    require "server:constants"
    require "server:std/stdmin"

    local protect = require "server:lib/private/protect"
    if protect.protect_require() then return end


    if IS_RELEASE then
        logger.log(LOGO)
    else
        logger.log(string.multiline_concat(LOGO, DEV))
    end

    logger.log(string.format("Welcome to %s! Starting...", PROJECT_NAME))
    logger.log(string.format([[

    %s status:
        release: %s
        version: %s
    ]], PROJECT_NAME, IS_RELEASE, SERVER_VERSION))

    local lib = require "server:lib/private/min"

    require "server:init/server"
    require "server:multiplayer/server/chat/commands"

    local timeout_executor = require "server:lib/private/common/timeout_executor"
    local server = require "server:multiplayer/server/server"

    local metadata = require "server:lib/private/files/metadata"
    local world = lib.world

    _G["/$p"] = table.copy(package.loaded)
    local events_handlers = table.copy(events.handlers)

    require "server:init/engine_patcher"

    IS_RUNNING = true
    world.open_main()
    logger.log("world loop is started")

    events.handlers["server:save"] = events_handlers["server:save"]
    events.handlers["server:main_tick"] = events_handlers["server:main_tick"]
    events.handlers["server:client_connected"] = events_handlers["server:client_connected"]
    events.handlers["server:client_disconnected"] = events_handlers["server:client_disconnected"]
    events.handlers["server:client_pipe_start"] = events_handlers["server:client_pipe_start"]
    events.handlers["server:player_ground_landing"] = events_handlers["server:player_ground_landing"]

    local save_interval = CONFIG.server.auto_save_interval * 60
    local shutdown_timeout = (CONFIG.server.shutdown_timeout or -1) * 60
    local last_time_save = 0

    metadata.load()

    server = server.new(CONFIG.server.port)
    server:start()

    logger.log("server is started")

    tests()
end

main()