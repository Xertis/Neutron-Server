PACK_ID = "server"

--Конфиг
CONFIG_PATH = "config:server_config.json"
CONFIG = {no_init = true} --Инициализируется в std

--Сервер
IS_RUNNING = false

--Сессия
if not Session then
    Session = {}

    Session.client = nil
    Session.server = nil
    Session.username = nil
    Session.ip = nil
    Session.port = nil

end