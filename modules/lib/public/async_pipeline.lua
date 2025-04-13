local asyncio = require "lib/public/asyncio/init"
local async = asyncio.async

local Pipeline = {}
Pipeline.__index = Pipeline

function Pipeline.new()
    local self = setmetatable({}, Pipeline)

    self._middlewares = {}
    self.loop = {}

    return self
end

function Pipeline:add_middleware(func)
    if type(func) == "function" then

        table.insert( self._middlewares, func )
    end
end

function Pipeline:process( data, loop )
    local result = data or true
    self.loop = loop
    for index, callback in ipairs(self._middlewares) do
        local async_callback = async(function (_result)
            return callback( _result )
        end)

        if result then
            result = loop:await(async_callback(result))
        else
            break
        end

    end

    return result
end

return Pipeline