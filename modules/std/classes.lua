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
Module.__index = Module

setmetatable(Module, {
    __call = function(_, module)
        return Module.new(module or {})
    end
})

function Module.new(module)
    local self = setmetatable({}, Module)

    self.shared = table.deep_copy(module)
    self.single = AutoTable()
    self.headless = AutoTable()

    return self
end

function Module:build()
    local side = IS_HEADLESS and self.headless or self.single

    return table.deep_merge(side, self.shared)
end
