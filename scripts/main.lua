app.config_packs({ "server" })
app.load_content()
require "server:std/stdboot"

LAUNCH_ATTEMPTS = 1

local function main()
    require "server:globals"
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

    if IS_FIRST_RUN then
        logger.log("The first startup was detected, server has been stopped.")
        logger.log(
            "A configuration file was created on the config:server_config.json. Please configure the settings and restart.")
        return
    end

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

    local neutron_events = {
        "server:save", "server:main_tick",
        "server:client_connected", "server:client_disconnected",
        "server:client_pipe_start", "server:player_ground_landing"
    }

    for _, event_name in ipairs(neutron_events) do
        events.handlers[event_name] = table.merge(events_handlers[event_name] or {}, events.handlers[event_name] or {})
    end

    local save_interval = CONFIG.server.auto_save_interval * 60
    local shutdown_timeout = (CONFIG.server.shutdown_timeout or -1) * 60
    local last_time_save = 0

    metadata.load()

    server = server.new(CONFIG.server.port)
    server:start()

    logger.log("server is started")

    while IS_RUNNING do
        local ctime = math.round(time.uptime())
        LAST_SERVER_UPDATE = os.time()

        app.tick()
        timeout_executor.process()
        server:tick()

        events.emit("server:main_tick")

        if ctime % save_interval == 0 and ctime - last_time_save > 1 then
            logger.log("Saving world...")
            last_time_save = ctime
            events.emit("server:save")
            metadata.save()
            app.save_world()
        end

        if ctime > shutdown_timeout and shutdown_timeout > 0 then
            metadata.save()
            IS_RUNNING = false
        end
    end

    server:stop()
    logger.log("world loop is stoped. Server is now offline.")
    logger.log("Saving and closing the world...")
    world.close_main()
end

-- do
--     local compiler = require "server:multiplayer/protocol-kernel/compiler"
--     local bb = require "server:lib/public/bit_buffer":new()

--     local decoder = compiler.compile_decoder({"particle"})
--     local encoder = compiler.compile_encoder({"particle"})

--     print(encoder)
--     print(decoder)
-- end

local PROCESS_NAME = "KERNEL-BOOTLOADER"
while LAUNCH_ATTEMPTS <= 1 do
    logger.log(string.format("Launch attempt number: %s", LAUNCH_ATTEMPTS), nil, nil, PROCESS_NAME)
    LAUNCH_ATTEMPTS = LAUNCH_ATTEMPTS + 1

    local status, err = pcall(main)

    if not status then
        logger.log(string.format("Failed with an error: %s", err), nil, nil, PROCESS_NAME)
    else
        logger.log(string.format("Shutdown successfully", PROCESS_NAME), nil, nil, PROCESS_NAME)
        break
    end
end
