app.config_packs({"server"})
app.load_content()

local lib = require "server:lib/private/min"
if lib.protect.protect_require() then return end

require "server:constants"
require "server:init/server"

local server = lib.server
local world = lib.world

world.open_main()
server.log("world loop is started")
IS_RUNNING = true

local save_interval = CONFIG.server.auto_save_interval * 60
local last_time_save = 0

while IS_RUNNING do
    app.tick()

    local ctime = math.round(time.uptime())
    if ctime % save_interval == 0 and ctime - last_time_save > 1 then
        server.log("Saving world...")
        last_time_save = ctime
        app.save_world()
    end
end

server.log("world loop is stoped. Saving world...")
app.save_world()