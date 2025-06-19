PACK_ID = "server"

--Конфиг
CONFIG_PATH = "config:server_config.json"
CONFIG = {} --Инициализируется в std

--Песочница
RENDER_DISTANCE = 0
PLAYER_ENTITY_ID = nil
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
IS_RELEASE = false
SERVER_VERSION = json.parse(file.read("server:package.json")).version
PROJECT_NAME = "Neutron"
LOGO = [[
                                               
    _   __              __                     
   / | / /___   __  __ / /_ _____ ____   ____  
  /  |/ // _ \ / / / // __// ___// __ \ / __ \ 
 / /|  //  __// /_/ // /_ / /   / /_/ // / / / 
/_/ |_/ \___/ \____/ \__//_/    \____//_/ /_/  
                                               
]]

DEV = [[
                    
      ___           
     / _ \___ _  __ 
    / // / -_) |/ / 
   /____/\__/|___/  
                    
]]

--Прочее
USER_ICON_PATH = "user:icon.png"
DEFAULT_ICON_PATH = "server:default_data/server-icon.png"