app.config_packs({"server", "base"})
app.load_content()

require "server:constants"
require "server:std/std"

server.log("main initialized")

server.log("start world loop")
while true do
    app.tick()
end