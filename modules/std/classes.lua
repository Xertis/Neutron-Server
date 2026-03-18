AutoTable = {}

local function reset_metatable(tbl)
    local result = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" and getmetatable(v) == AutoTable.mt then
            result[k] = reset_metatable(v)
        else
            result[k] = v
        end
    end
    return result
end

AutoTable.mt = {
    __index = function(tbl, key)
        if key == "to_table" then
            return reset_metatable
        end

        local new_tbl = AutoTable()
        rawset(tbl, key, new_tbl)
        return new_tbl
    end
}

setmetatable(AutoTable, {
    __call = function(_, tbl)
        return setmetatable(tbl or {}, AutoTable.mt)
    end
})

----------------

Module = {}

setmetatable(Module, {
    __call = function(self, module)
        return self.new(module or {})
    end
})

Module.__index = function(self, key)
    if Module[key] then
        return Module[key]
    end

    if self.module and self.module[key] then
        return self.module[key]
    end
end

function Module.new(module)
    local self = setmetatable({}, Module)

    self.module = {}
    self.shared = table.deep_copy(module)
    self.single = AutoTable()
    self.headless = AutoTable()

    return self
end

function Module:build()
    local side = IS_HEADLESS and self.headless or self.single

    self.module = table.deep_merge(side:to_table(), self.shared)

    return self.module
end
