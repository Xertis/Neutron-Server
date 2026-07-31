require "server:std/boot"

LAUNCH_ATTEMPTS = 1

local function tests()
    import "tests/bit_buffer"
    import "tests/player_entity"
    import "tests/edd"
    import "tests/external_buffer"
    import "tests/varint"
    import "tests/module"

    logger.log("All tests passed", "T")
end

local function main()
    import "globals"
    import "std/min"
    import "std/classes"

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
