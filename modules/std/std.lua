require "std/stdmin"
local world = require "std/stdworld"

--Проверка на наличие файла конфига
if not file.exists(CONFIG_PATH) then
    file.write(CONFIG_PATH, file.read(PACK_ID .. ":default_data/server_config.json"))
end

--Загружаем конфиг
if CONFIG.no_init == true then
    CONFIG = json.parse(file.read(CONFIG_PATH))
end

world.open()

server.log("std initialized")