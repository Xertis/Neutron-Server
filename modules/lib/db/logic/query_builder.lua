local utils = require "lib/public/database/utils/utils"
local parser = require "lib/public/database/files/db_parser"
local Query = {}
Query.__index = Query

function Query.new(session, table_name)
    local self = setmetatable({}, Query)
    self.session = session
    self.table_name = table_name
    self.filters = {}
    self.limit_value = nil
    self.order_by_value = nil
    self.reversed_order_by = false
    return self
end

function Query:filter(condition)
    table.insert(self.filters, condition)
    return self
end

function Query:limit(num)
    self.limit_value = num
    return self
end

function Query:order_by(field, reversed)
    self.order_by_value = field
    self.reversed_order_by = reversed or false
    return self
end

function Query:all()
    local table_data = self:_get_table_data()
    local results = {}

    for _, row in ipairs(table_data) do
        if self:_matches_filters(row) then
            table.insert(results, row)
        end
    end
    -- 01 1
    -- 11 0
    -- 10 1
    -- 00 0

    -- 01 1
    -- 10 1
    -- 11 0
    -- 00 0

    if self.order_by_value then
        table.sort(results, function(a, b)
            a = a[self.order_by_value]
            b = b[self.order_by_value]
            local is_reversed = self.reversed_order_by

            if a == nil and b ~= nil then
                return true ~= is_reversed
            elseif a ~= nil and b ==  nil then
                return false ~= is_reversed
            elseif a == nil and b == nil then
                return false ~= is_reversed
            end

            return a < b ~= is_reversed
        end)
    end

    if self.limit_value and #results > self.limit_value then
        results = {unpack(results, 1, self.limit_value)}
    end

    return results
end

function Query:first()
    local results = self:all()
    return results[1]
end

function Query:last()
    local results = self:all()
    return results[#results]
end

function Query:count()
    local results = self:all()
    return #results
end

function Query:_get_table_data()
    local table_path = file.join(utils.tables_path, self.session.pack, self.table_name)
    local bytes = file.read_bytes(table_path)
    return parser.deserialize(bytes)
end

function Query:_matches_filters(row)
    for _, filter in ipairs(self.filters) do
        for field, condition in pairs(filter) do
            if type(condition) == "table" then

                for op, value in pairs(condition) do
                    if op == "==" and row[field] ~= value then
                        return false
                    elseif op == "~=" and row[field] == value then
                        return false
                    elseif op == ">" and row[field] <= value then
                        return false
                    elseif op == "<" and row[field] >= value then
                        return false
                    elseif op == ">=" and row[field] < value then
                        return false
                    elseif op == "<=" and row[field] > value then
                        return false
                    elseif op == "in" and not table.has(value, row[field]) then
                        return false
                    elseif op == "not_in" and table.has(value, row[field]) then
                        return false
                    end
                end
            else
                if row[field] ~= condition then
                    return false
                end
            end
        end
    end
    return true
end

return Query