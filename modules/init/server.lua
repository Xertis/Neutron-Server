require "std/stdmin"
require "std/stdworld"

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

app.reconfig_packs(CONFIG.game.content_packs, {})
world.preparation_main()

server.log("world initialized")
