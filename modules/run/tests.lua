require "server:std/boot"

LAUNCH_ATTEMPTS = 1

local function tests()
    require "server:tests/player_entity"
    require "server:tests/edd"
    require "server:tests/external_buffer"
    require "server:tests/varint"

    logger.log("All tests passed", "T")
end

local function main()
    require "server:globals"
    require "server:std/min"

    if IS_RELEASE then
        logger.log("\n" .. LOGO)
    else
        logger.log("\n" .. string.multiline_concat(LOGO, DEV))
    end

    logger.log(string.format("Welcome to %s! Starting...", PROJECT_NAME))
    logger.log(string.format([[

    %s status:
        release: %s
        version: %s
    ]], PROJECT_NAME, IS_RELEASE, SERVER_VERSION))


    require "server:init/server"
    require "server:core/sandbox/chat/commands"

    tests()
end

main()
