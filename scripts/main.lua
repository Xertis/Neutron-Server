app.config_packs({"server"})
app.load_content()

require "server:constants"
require "server:init/server"

world.open_main()
server.log("start world loop")
IS_RUNNING = true

local save_interval = CONFIG.server.auto_save_interval * 60
local last_time_save = 0

while IS_RUNNING do
    app.tick()

    local ctime = math.round(time.uptime())
    if ctime % save_interval == 0 and ctime - last_time_save > 1 then
        server.log("save world")
        last_time_save = ctime
        app.save_world()
    end
end

server.log("world loop is stoped")
app.save_world()