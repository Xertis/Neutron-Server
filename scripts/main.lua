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

    if IS_FIRST_RUN then
        logger.log("The first startup was detected, server has been stopped.")
        logger.log("A configuration file was created on the config:server_config.json. Please configure the settings and restart.")
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

    events.handlers["server:save"] = events_handlers["server:save"]
    events.handlers["server:client_connected"] = events_handlers["server:client_connected"]
    events.handlers["server:client_disconnected"] = events_handlers["server:client_disconnected"]

    local save_interval = CONFIG.server.auto_save_interval * 60
    local last_time_save = 0

    metadata.load()

    server = server.new(CONFIG.server.port)
    server:start()



    logger.log("server is started")

    while IS_RUNNING do
        app.tick()
        timeout_executor.process()
        server:tick()

        local ctime = math.round(time.uptime())
        if ctime % save_interval == 0 and ctime - last_time_save > 1 then
            logger.log("Saving world...")
            last_time_save = ctime
            events.emit("server:save")
            metadata.save()
            app.save_world()
        end
    end

    server:stop()
    logger.log("world loop is stoped. Server is now offline.")
    logger.log("Saving and closing the world...")
    world.close_main()
end

local status, err = pcall(main)
if not status then
    print("Launch failed with an error: ", err)
end