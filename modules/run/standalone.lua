require "server:std/stdboot"
require "server:globals"
IS_HEADLESS = false

require "server:std/stdmin"

logger.log("Launching Neutron in standalone mode...")

-- Чтобы start_require работал как обычный require
_G["/$p"] = package.loaded

local lib = require "server:lib/private/min"

require "server:init/engine_patcher"
require "server:init/server"
require "server:multiplayer/server/chat/commands"

local timeout_executor = require "server:lib/private/common/timeout_executor"
local server = require "server:multiplayer/server/server"

local metadata = require "server:lib/private/files/metadata"
local world = lib.world
IS_RUNNING = true
world.open_main()

metadata.load()
server = server.new(CONFIG.server.port)
server:start_main()

-- Совершаем невозможное, знакомим сервер и клиент
require(string.format("client:api/%s/shell/api", _G["$Multiplayer"].api_references.Neutron.latest)).__run_in_standalone(
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
