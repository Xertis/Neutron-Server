local loops = require "lib/public/asyncio/event_loop"
local futures = require "lib/public/asyncio/futures"
local tasks = require "lib/public/asyncio/tasks"
local timers = require "lib/public/asyncio/timer_list"
local sync = require "lib/public/asyncio/synchronization"
local queues = require "lib/public/asyncio/queues"

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