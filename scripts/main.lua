app.config_packs({"server"})
app.load_content()

local protect = require "server:lib/private/protect"
if protect.protect_require() then return end

local lib = require "server:lib/private/min"

require "server:constants"
require "server:init/server"
require "server:multiplayer/server/chat/commands"

local timeout_executor = require "server:lib/private/common/timeout_executor"
local server = require "server:multiplayer/server/server"
local metadata = require "server:lib/private/files/metadata"
local world = lib.world

_G["/$p"] = table.copy(package.loaded)

IS_RUNNING = true
world.open_main()
logger.log("world loop is started")

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
        metadata.save()
        app.save_world()
    end
end

server:stop()
logger.log("world loop is stoped. Server is now offline.")
logger.log("Saving and closing the world...")
app.close_world(true)