app.config_packs({"server"})
app.load_content()
require "server:std/stdboot"

LAUNCH_ATTEMPTS = 1

local function tests()
    require "server:tests/player_entity"
    require "server:tests/edd"

    logger.log("All tests passed", "T")
end

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
    

    require "server:init/server"
    require "server:multiplayer/server/chat/commands"

    tests()
end

main()