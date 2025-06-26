app.config_packs({"server"})
app.load_content()
require "server:std/stdboot"

LAUNCH_ATTEMPTS = 1

local function eval(encode, decode, val)
    local bit_buffer = require "server:lib/public/bit_buffer"
    local status, res = pcall(function ()
        local buf = bit_buffer:new()
        encode(buf, val)

        buf:flush()
        buf:reset()

        local res = decode(buf)[1]

        return table.deep_equals(val, res)
    end)

    if not status or not res then
        print(json.tostring(val))
        error("Error: " .. tostring(res))
    end
end

local function tests()
    -- Тест парсеров пакетов
    logger.log("Start of tests", "T")
    local compiler = require "server:multiplayer/protocol-kernel/compiler"
    local bit_buffer = require "server:lib/public/bit_buffer"

    -- Тест инвентаря

    local encoder = compiler.compile_encoder({"Inventory"})
    local decoder = compiler.compile_decoder({"Inventory"})

    local encoder_compil = compiler.load(encoder)
    local decoder_compil = compiler.load(decoder)

    local Inventory = {}
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

    eval(encoder_compil, decoder_compil, Inventory)
    logger.log("Inventory type test passed", "T")

    -- Тест PlayerEntity

    encoder = compiler.compile_encoder({"PlayerEntity"})
    decoder = compiler.compile_decoder({"PlayerEntity"})

    encoder_compil = compiler.load(encoder)
    decoder_compil = compiler.load(decoder)

    local player = {}

    if math.random() > 0.5 then
        player.pos = {
            math.random() * 200 - 100,
            math.random() * 100,
            math.random() * 200 - 100
        }
    end

    if math.random() > 0.5 then
        player.rot = {
            math.random() * 360 - 180,
            math.random() * 360 - 180
        }
    end

    if math.random() > 0.7 then
        player.cheats = {
            math.random() > 0.5,
            math.random() > 0.5
        }
    end

    eval(encoder_compil, decoder_compil, player)
    logger.log("PlayerEntity type test passed", "T")

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

    metadata.load()

    tests()
end

main()