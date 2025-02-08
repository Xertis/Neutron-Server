require "std/stdmin"
require "std/stdworld"

--Проверка на наличие файла конфига
if not file.exists(CONFIG_PATH) then
    file.write(CONFIG_PATH, file.read(PACK_ID .. ":default_data/server_config.json"))
end

--Загружаем конфиг
if CONFIG.no_init == true then
    CONFIG = json.parse(file.read(CONFIG_PATH))
end

app.reconfig_packs(CONFIG.game.content_packs, {})

world.open_main()

server.log("std initialized")