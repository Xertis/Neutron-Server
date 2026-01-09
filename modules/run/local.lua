local protect = require "server:lib/private/protect"
if protect.protect_require() then return end

return function (port)
    require "server:std/stdboot"
    require "server:globals"
    require "server:std/stdmin"

    local lib = require "server:lib/private/min"

    require "server:init/engine_patcher"
    require "server:init/server"
    require "server:multiplayer/server/chat/commands"

    local timeout_executor = require "server:lib/private/common/timeout_executor"
    local server = require "server:multiplayer/server/server"
    local metadata = require "server:lib/private/files/metadata"

    local world = lib.world

    IS_RUNNING = true
    world.open_main_in_local()

    metadata.load()
    server = server.new(port)
    server:start()

    events.emit("server:__initialization_completed")

    events.on("server:__world_tick", function ()
        LAST_SERVER_UPDATE = os.time()

        timeout_executor.process()
        server:tick()

        events.emit("server:main_tick")
    end)

    events.on("server:__world_save", function ()
        logger.log("Saving world...")
        events.emit("server:save")
        metadata.save()
    end)
end