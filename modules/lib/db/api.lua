local utils = require "lib/public/database/utils/utils"
local session = require "lib/public/database/session"
local CODES = json.parse(file.read("server:modules/lib/public/database/data/codes.json"))

local db = {
    types = utils.types,
    db = {},
    items = {},
}

local function get_name()
    local pack_name, _ = parse_path(debug.getinfo(2).source)
    return pack_name
end

function db.db.register()
    if not file.exists(utils.tables_path) then
        file.mkdir(utils.tables_path)
    end

    local pack_name = get_name()
    if utils.db.exists(pack_name) then
        return CODES.db.DatabaseExists
    end

    file.mkdir(utils.tables_path .. pack_name, pack_name)
    return CODES.Success
end

function db.db.login()
    local pack_name = get_name()
    if not utils.db.exists(pack_name) then
        return CODES.db.DatabaseNotExists
    end

    return session.new(pack_name)
end

db.db.exists = utils.db.exists

function db.items.Column(type, config)
    config = config or {}
    return {type = type, config = config}
end

return db