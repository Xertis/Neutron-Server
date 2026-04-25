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

----------------

-- Запрещён на территории РФ
SpeedTest = {}
SpeedTest.__index = SpeedTest
setmetatable(SpeedTest, {
    __call = function(self, func, name)
        return self.new(func, name)
    end
})

function SpeedTest.new(func, name)
    local self = setmetatable({}, SpeedTest)

    self.func = func
    self.name = name
    self.calls_time_sum = 0
    self.calls_count = 0

    return self
end

function SpeedTest:reset()
    self.calls_time_sum = 0
    self.calls_count = 0
end

function SpeedTest:test(...)
    local start_time = os.clock()
    local res = { self.func(...) }
    local end_time = os.clock()

    self.calls_time_sum = self.calls_time_sum + (end_time - start_time)
    self.calls_count = self.calls_count + 1

    if self.calls_count % 1000 == 0 then
        self:result()
    end

    return unpack(res)
end

function SpeedTest:result()
    print(string.format("[%s] Average: %s", self.name, self.calls_time_sum / self.calls_count))
end

PPSCounter = {}
PPSCounter.__index = PPSCounter

setmetatable(PPSCounter, {
    __call = function(self, name)
        return self.new(name)
    end
})

function PPSCounter.new(name)
    local self = setmetatable({}, PPSCounter)

    self.name = name
    self.count_in_second = 0
    self.last_time = os.time()

    self.all_count = 0
    self.seconds_sum = 0

    self.packet_data = {}

    return self
end

function PPSCounter:reset()
    self.count_in_second = 0
    self.last_time = os.time()
    self.all_count = 0
    self.seconds_sum = 0
    self.packet_data = {}
end

function PPSCounter:tick(packet_type)
    self.count_in_second = self.count_in_second + 1
    self.all_count = self.all_count + 1

    if packet_type then
        self.packet_data[packet_type] = (self.packet_data[packet_type] or 0) + 1
    end

    local current_time = os.time()
    local delta = current_time - self.last_time

    if delta >= 1 then
        self.seconds_sum = self.seconds_sum + delta
        self.count_in_second = 0
        self.last_time = current_time

        if self.seconds_sum > 0 and self.seconds_sum % 10 == 0 then
            self:result()
            self:reset()
        end
    end
end

function PPSCounter:result()
    if self.seconds_sum == 0 then return end

    local average = self.all_count / self.seconds_sum

    local max_count = 0
    local most_frequent = "nil"

    for p_type, p_count in pairs(self.packet_data) do
        if p_count > max_count then
            max_count = p_count
            most_frequent = p_type
        end
    end

    print(string.format("[%s] Прошло сек: %d | Средний PPS: %.2f | Топ пакет: %s (%d шт.)",
        self.name, self.seconds_sum, average, most_frequent, max_count))
end
