local lib = require "lib/private/min"
local protect = require "lib/private/protect"

if protect.protect_require() then return end

local world = lib.world

logger.log("std initialized")

--Проверка на наличие файла конфига
if not file.exists(CONFIG_PATH) then
    file.write(CONFIG_PATH, file.read(PACK_ID .. ":default_data/server_config.json"))
end

--Загружаем конфиг
if CONFIG.no_init == true then
    CONFIG = table.freeze(json.parse(file.read(CONFIG_PATH)))
end

logger.log("config initialized")

world.preparation_main()

logger.log("world initialized")
