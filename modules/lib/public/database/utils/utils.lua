local parser = require "lib/public/database/files/db_parser"

local utils = {
    tables_path = "world:databases",
    db = {},
    tables = {},
    valid = {},
    types = parser.types
}

function utils.db.exists(pack_name)
    if file.exists(utils.tables_path .. pack_name) then
        return true
    end

    return false
end

function utils.tables.exists(pack_name, tbl)
    if file.exists(file.join(utils.tables_path, pack_name, tbl)) then
        return true
    end

    return false
end

function utils.valid.primary_key_type(key_type)
    if type(key_type) == "string" then
        key_type = utils.types.codes[key_type]
    end

    local valid_types = {
        utils.types.codes.uint8,
        utils.types.codes.uint16,
        utils.types.codes.uint32,
        utils.types.codes.int64
    }

    return table.has(valid_types, key_type)
end

function utils.valid.key_type(key_type)
    if type(key_type) == "string" then
        return utils.types.codes[key_type] ~= nil and key_type ~= "null"
    elseif type(key_type) == "number" then
        return utils.types.indexes[key_type] ~= nil and key_type ~= 0
    else
        return false
    end
end

return utils
