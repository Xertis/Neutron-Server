require "server:std/boot"

LAUNCH_ATTEMPTS = 1

local function tests()
    import "server:tests/player_entity"
    import "server:tests/edd"
    import "server:tests/external_buffer"
    import "server:tests/varint"

    logger.log("All tests passed", "T")
end

local function main()
    import "server:globals"
    import "server:std/min"
    import "server:std/classes"

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
