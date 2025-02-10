local lib = require "lib/private/min"
local protect = require "lib/private/protect"

if protect.protect_require() then return end

local world = lib.world

logger.log("std initialized")

--Проверка на наличие файла конфига
do
    if not file.exists(CONFIG_PATH) then
        file.write(CONFIG_PATH, file.read(PACK_ID .. ":default_data/server_config.json"))
    end
end

--Загружаем конфиг
do
    if CONFIG.no_init == true then
        CONFIG = table.freeze(json.parse(file.read(CONFIG_PATH)))
    end
end

logger.log("config initialized")

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

logger.log("settings initialized")

world.preparation_main()
logger.log("world initialized")
