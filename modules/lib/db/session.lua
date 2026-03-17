local utils = require "lib/public/database/utils/utils"
local parser = require "lib/public/database/files/db_parser"
local Query = require "lib/public/database/logic/query_builder"
local Session = {}
Session.__index = Session

local function create_table(pack_name, table_name, keys, primary_key)
    if utils.tables.exists(pack_name, table_name) then
        return
    end

    local table_path = file.join(utils.tables_path, pack_name, table_name)

    local bytes = parser.serialize({}, keys, primary_key)
    file.write_bytes(table_path, bytes)
end

local function get_table_data(pack, table_name)
    local table_path = file.join(utils.tables_path, pack, table_name)
    local bytes = file.read_bytes(table_path)
    return parser.deserialize(bytes)
end

function Session.new(pack_name)
    local self = setmetatable({}, Session)

    self.pack = pack_name
    self.tables = {}

    return self
end

function Session:init_table(config)
    local res = {
        annotation_keys = {},
        keys = {}
    }
    local primary_key = false

    local table_name = config["__tablename__"]
    config["__tablename__"] = nil

    for key, type in pairs(config) do
        if type.config.primary_key and not primary_key then
            if not utils.valid.primary_key_type(type.type) then
                error("invalid primary_key type! Valid types: uint8, uint16, uint32, int64")
            end

            primary_key = key
        elseif type.config.primary_key then
            error("Duplicated primary_key")
        end

        if not utils.valid.key_type(type.type) then
            error("Invalid key type: " .. type.type)
        end
        res.keys[key] = type
        table.insert(res.annotation_keys, {key, type.type})
    end

    if not primary_key then
        error("primary_key has not been assigned")
    end

    res.primary_key = primary_key
    self.tables[table_name] = res

    create_table(self.pack, table_name, res.annotation_keys, res.primary_key)
end

function Session:query(table_name)
    if not self.tables[table_name] then
        error("Table " .. table_name .. " not initialized")
    end

    return Query.new(self, table_name)
end

function Session:add(table_name, data)
    local table_info = self.tables[table_name]
    if not table_info then
        error("Table " .. table_name .. " not initialized")
    end

    for key, value in pairs(data) do
        local key_info = table_info.keys[key]
        if not key_info then
            error("Unknown field '" .. key .. "' in table " .. table_name)
        end
    end

    local table_path = file.join(utils.tables_path, self.pack, table_name)
    local bytes = file.read_bytes(table_path)
    local table_data = parser.deserialize(bytes)

    local max_primary_key = -1
    for _, row in ipairs(table_data) do
        max_primary_key = math.max(max_primary_key, row[table_info.primary_key])
    end

    data[table_info.primary_key] = max_primary_key+1

    table.insert(table_data, data)
    file.write_bytes(table_path, parser.serialize(table_data, table_info.annotation_keys, table_info.primary_key))
end

function Session:update(table_name, primary_key, new_data)
    local table_info = self.tables[table_name]

    if not table_info then
        error("Table " .. table_name .. " not initialized")
    elseif type(new_data) ~= "table" then
        error("Invalid new_data argument")
    elseif type(primary_key) ~= "number" then
        error("Invalid primary_key argument")
    end

    local table_data = get_table_data(self.pack, table_name)
    local table_path = file.join(utils.tables_path, self.pack, table_name)
    for i, row in ipairs(table_data) do
        if row[table_info.primary_key] == primary_key then
            new_data[table_info.primary_key] = primary_key
            table_data[i] = new_data
            break
        end
    end

    file.write_bytes(table_path, parser.serialize(table_data, table_info.annotation_keys, table_info.primary_key))
end

function Session:delete(table_name, rows)
    local table_info = self.tables[table_name]

    if not table_info then
        error("Table " .. table_name .. " not initialized")
    elseif type(rows) ~= "table" then
        error("Invalid rows argument")
    elseif type(rows[1]) ~= "table" and #rows > 0 then
        error("Invalid rows argument")
    end

    local table_data = get_table_data(self.pack, table_name)
    local table_path = file.join(utils.tables_path, self.pack, table_name)
    local new_data = {}

    for _, row in ipairs(table_data) do
        for _, row_to_del in ipairs(rows) do
            if row[table_info.primary_key] ~= row_to_del[table_info.primary_key] then
                table.insert(new_data, row)
            end
        end
    end

    file.write_bytes(table_path, parser.serialize(new_data, table_info.annotation_keys, table_info.primary_key))
end

function Session:remove_table(table_name)
    local table_info = self.tables[table_name]
    if not table_info then
        error("Table " .. table_name .. " not initialized")
    end

    self.tables[table_name] = nil
    local table_path = file.join(utils.tables_path, self.pack, table_name)
    file.remove(table_path)
end

return Session