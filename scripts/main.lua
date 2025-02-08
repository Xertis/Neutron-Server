app.config_packs({"server"})
app.load_content()

require "server:constants"
require "server:std/std"

server.log("main initialized")

server.log("start world loop")
IS_RUNNING = true
while IS_RUNNING do
    app.tick()
end