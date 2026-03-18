AutoTable = {}

setmetatable(AutoTable, {
    __call = function(_, tbl)
        tbl = tbl or {}

        setmetatable(tbl, {
            __index = function(_tbl, key)
                rawset(_tbl, key, {})
                return _tbl[key]
            end
        })

        return tbl
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
    self.module = table.deep_merge(setmetatable(side, {}), self.shared)

    return self.module
end
