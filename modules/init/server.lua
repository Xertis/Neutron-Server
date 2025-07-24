local lib = require "lib/private/min"
local protect = require "lib/private/protect"

if protect.protect_require() then return end

local world = lib.world

logger.log("std initialized")

--Проверка на наличие файла конфига
do
    if not file.exists(CONFIG_PATH) then
        file.write(CONFIG_PATH, file.read(PACK_ID .. ":default_data/server_config.json"))
        IS_FIRST_RUN = true
    end
end

--Загружаем конфиг
do
    CONFIG = json.parse(file.read(CONFIG_PATH))

    if CONFIG.server.chunks_loading_distance > 255 then
        CONFIG.server.chunks_loading_distance = 255
        logger.log("Chunks distance is too high. Please select a value in the range of 0-255. The current chunks distance is set to 255", 'W')
    end

    CONFIG = table.freeze(CONFIG)

    RENDER_DISTANCE = (CONFIG.server.chunks_loading_distance + 2) * 16
end

logger.log("config initialized")

if IS_FIRST_RUN then
    return
end

--Загружаем константы песочницы

do
    CODES = json.parse(file.read(CODES.codes_path))
    CODES = table.freeze(CODES)
end

logger.log("sandbox const initialized")

--Загружаем настройки
do
    local settings = {
        ["chunks_loading_distance"] = "chunks.load-distance",
        ["chunks_loading_speed"] = "chunks.load-speed"
    }

    for cname, sname in pairs(settings) do
        app.set_setting(sname, CONFIG.server[cname])
    end
end

--Другое
do
    RESERVED_USERNAMES = table.freeze(RESERVED_USERNAMES)
end

logger.log("settings initialized")

world.preparation_main()
logger.log("world initialized")