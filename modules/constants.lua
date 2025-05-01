PACK_ID = "server"

--Конфиг
CONFIG_PATH = "config:server_config.json"
CONFIG = {} --Инициализируется в std

--Песочница
CODES = {
    codes_path = "server:default_data/codes.json"
}

--Аккаунты
RESERVED_USERNAMES = {
    "server",
    "root",
    "admin"
}

--Сервер
IS_RUNNING = false
IS_FIRST_RUN = false
LOGO = [[

__   __  _______  __   __  _______  ___      _______  __    _  ___      ___   __    _  _______ 
|  | |  ||       ||  |_|  ||       ||   |    |       ||  |  | ||   |    |   | |  |  | ||       |
|  |_|  ||   _   ||       ||    ___||   |    |   _   ||   |_| ||   |    |   | |   |_| ||    ___|
|       ||  | |  ||       ||   |___ |   |    |  | |  ||       ||   |    |   | |       ||   |___ 
|       ||  |_|  | |     | |    ___||   |___ |  |_|  ||  _    ||   |___ |   | |  _    ||    ___|
 |     | |       ||   _   ||   |___ |       ||       || | |   ||       ||   | | | |   ||   |___ 
  |___|  |_______||__| |__||_______||_______||_______||_|  |__||_______||___| |_|  |__||_______|
]]

--Сессия
if not Session then
    Session = {}

    Session.client = nil
    Session.server = nil
    Session.username = nil
    Session.ip = nil
    Session.port = nil

end

--Прочее
USER_ICON_PATH = "user:icon.png"
DEFAULT_ICON_PATH = "server:default_data/server-icon.png"