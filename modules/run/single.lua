require "server:std/boot"
import "server:globals"

IS_HEADLESS = false

import "server:std/min"
import "server:std/classes"

logger.log("Launching Neutron in single mode...")

local lib = import "server:lib/utils/min"

import "server:init/engine_patcher"
import "server:init/server"
import "server:core/sandbox/chat/commands"

local timeout_executor = import "server:lib/flow/timeout_executor"
local server = import "server:net/classes/server"

local metadata = import "server:lib/data/metadata"
local world = lib.world

IS_RUNNING = true
world.open_main()

metadata.load()
server = server.new(CONFIG.server.port)
server:start_main()

-- Совершаем невозможное, знакомим сервер и клиент
require(string.format("client:api/%s/shell/api", _G["$Multiplayer"].api_references.Neutron.latest)).__run_in_single(
    CONFIG.server.port)

events.on("server:.worldtick", function()
    timeout_executor.process()
    server:tick()

    events.emit("server:main_tick")
end)

events.on("server:.worldsave", function()
    logger.log("Saving world...")
    events.emit("server:save")
    metadata.save()
end)
