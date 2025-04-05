local loops = require "lib/public/asyncio/event_loop"
local futures = require "lib/public/asyncio/futures"
local tasks = require "lib/public/asyncio/tasks"
local timers = require "lib/public/asyncio/timer_list"
local sync = require "lib/public/asyncio/synchronization"
local queues = require "lib/public/asyncio/queues"

local async_func = {}

function async_func:new(func, event_loop)

    local obj = {
        func = func,
        event_loop = event_loop
    }

    self.__index = self
    setmetatable(obj, self)

    return obj
end

function async_func:await(...)
	local args = {...}
	return self.event_loop:await(self.event_loop:async(function ()
		return self.func(unpack(args))
	end))
end

return {
	loops = loops,
	futures = futures,
	sync = sync,
	queues = queues,
	Task = tasks.Task,
	async = tasks.async,
	TimerList = timers.TimerList,
	get_event_loop = loops.get_event_loop
}