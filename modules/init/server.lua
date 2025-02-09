local lib = require "lib/private/min"

if lib.protect.protect_require() then return end

local server = lib.server
local world = lib.world

server.log("std initialized")

--Проверка на наличие файла конфига
if not file.exists(CONFIG_PATH) then
    file.write(CONFIG_PATH, file.read(PACK_ID .. ":default_data/server_config.json"))
end

--Загружаем конфиг
if CONFIG.no_init == true then
    CONFIG = json.parse(file.read(CONFIG_PATH))
end

server.log("config initialized")

world.preparation_main()

server.log("world initialized")
