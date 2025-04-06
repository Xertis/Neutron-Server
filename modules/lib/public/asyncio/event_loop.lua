local timers = require "lib/public/asyncio/timer_list"
local futures = require "lib/public/asyncio/futures"

local TimerList = timers.TimerList
local Future, FutureSemaphore = futures.Future, futures.FutureSemaphore

local get_event_loop
do
	local yield = coroutine.yield

	--[[@
		@name get_event_loop
		@desc Returns the event loop where the task is running on
		@returns EventLoop The EventLoop.
	]]
	function get_event_loop()
		return yield("get_event_loop")
	end
end

local EventLoop
do
	local time = os.time
	local yield = coroutine.yield

	EventLoop = {}
	local meta = {__index = EventLoop}

	--[[@
		@name new
		@desc Creates a new instance of EventLoop: an object that runs tasks concurrently (pseudo-paralellism)
		@desc /!\ EventLoop.tasks_index might be lower than the quantity of items in the EventLoop.tasks list. You must trust tasks_index.
		@desc /!\ EventLoop.removed_index might be lower than the quantity of items in the EventLoop.removed list. You must trust removed_index.
		@desc /!\ The tasks might run in a different order than the one they acquire once you run EventLoop:add_task
		@param obj?<table> The table to turn into an EventLoop.
		@returns EventLoop The EventLoop.
		@struct {
			timers = TimerList, -- A list of the timers the EventLoop will handle
			tasks = {}, -- The list of tasks the EventLoop is running
			removed = {}, -- The list of indexes in the tasks list to remove
			tasks_index = 0, -- The tasks list pointer
			removed_index = 0 -- The removed list pointer
		}
	]]
	function EventLoop.new(obj)
		obj = obj or {}
		obj.timers = TimerList.new()
		obj.tasks = {}
		obj.removed = {}
		obj.tasks_index = 0
		obj.removed_index = 0
		return setmetatable(obj, meta)
	end

	--[[@
		@name timers_callback
		@desc This function is called when a timer executes. It adds the timer task to the EventLoop.
		@desc This function doesn't use all the Timer arguments. Passsing the ones listed here is enough.
		@desc /!\ This function shouldn't be called by the user code, it should be called by timers only.
		@param callback<Timer> The timer that is being executed
		@paramstruct callback {
			task<Task> The task to execute.
		}
	]]
	function EventLoop.timers_callback(callback)
		callback.task.timer = nil
		return callback.event_loop:add_task(callback.task)
	end

	--[[@
		@name cancel_awaitable
		@desc This function is called when an awaitable times out.
		@desc This function doesn't use all the Timer arguments. Passsing the ones listed here is enough.
		@desc /!\ This function shouldn't be called by the user code, it should be called by timers only.
		@param callback<Timer> The timer that is being executed
		@paramstruct callback {
			awaitable<Future,Task> The awaitable to cancel.
		}
	]]
	function EventLoop.cancel_awaitable(callback)
		if not callback.awaitable.done then
			callback.awaitable:cancel()
		end
	end

	--[[@
		@name sleep
		@desc This function pauses the current task execution and resumes it after some time.
		@param delay<number> The time to sleep
	]]
	function EventLoop:sleep(delay)
		return self:sleep_until(time() + delay, self.current_task)
	end

	--[[@
		@name call_soon
		@desc This function appends the given task to the EventLoop list after some time.
		@param delay<number> The time to wait until the task can be appended
		@param task<Task> The task to append
		@param no_future?<boolean> Either to cancel the creation or not a Future object that will return after the task ends. @default false.
		@returns Future Returns the Future object if no_future is false.
	]]
	function EventLoop:call_soon(delay, task, no_future)
		return self:schedule(time() + delay, task, no_future)
	end

	--[[@
		@name sleep_until
		@desc The same as EventLoop:sleep, but with an absolute time.
		@param when<number> The time when the task will be resumed
	]]
	function EventLoop:sleep_until(when)
		self.current_task.timer = self.timers:add {
			callback = self.timers_callback,
			when = when or 0,
			task = self.current_task,
			event_loop = self
		}

		return self:stop_task_execution()
	end

	--[[@
		@name schedule
		@desc The same as EventLoop:call_soon, but with an absolute time.
		@param when<number> The time when the task can be appended
		@param task<Task> The task to append
		@param no_future?<boolean> Either to cancel the creation or not a Future object that will return after the task ends. @default false.
		@returns Future Returns the Future object if no_future is false.
	]]
	function EventLoop:schedule(when, task, no_future)
		if task.ran_once then
			error("Can't schedule a task that did already run or is running.")
		end

		task.timer = self.timers:add {
			callback = self.timers_callback,
			when = when or 0,
			task = task,
			event_loop = self
		}

		if not no_future then
			local future = self:new_object(Future)
			task:add_future(future)
			return future
		end
	end

	--[[@
		@name add_task
		@desc Adds a task to run on the next loop iteration.
		@param task<Task> The task to append
	]]
	function EventLoop:add_task(task)
		self.tasks_index = self.tasks_index + 1
		self.tasks[self.tasks_index] = task
	end

	--[[@
		@name new_object
		@desc Creates a new asyncio object that belongs to this EventLoop
		@param object<Future,Lock,Event,Queue> The object class
		@param vararg<mixed> The object arguments
		@returns mixed The new object
	]]
	function EventLoop:new_object(object, ...)
		return object.new(self, ...)
	end

	--[[@
		@name stop_task_execution
		@desc Pauses the task execution. This can be called from inside the task only.
		@desc /!\ The task doesn't resume again if you don't append it back later. If you don't do it, this will just stop forever the task execution.
	]]
	function EventLoop:stop_task_execution()
		self.current_task.paused = true
		return yield()
	end

	--[[@
		@name await
		@desc Awaits a Future or Task to complete. Pauses the current task and resumes it again once the awaitable is done.
		@param aw<Future,Task> The awaitable to wait.
		@returns mixed The Future or Task return values.
	]]
	function EventLoop:await(aw)
		if aw.cancelled or aw.done then
			error("Can't await a cancelled or done awaitable.", 2)
		end

		if aw._is_future then
			-- if it is a future object it can't be appended to the task list _yet_
			aw._next_tasks_index = aw._next_tasks_index + 1
			aw._next_tasks[aw._next_tasks_index] = self.current_task
		else
			if aw._next_task then
				error("Can't re-use a task. Use Futures instead.", 2)
			end

			aw.paused = false
			aw._next_task = self.current_task
			self:add_task(aw)
		end
		self.current_task.awaiting = aw
		return self:stop_task_execution()
	end

	--[[@
		@name await_safe
		@desc Awaits a Future or Task to complete, but safely. Returns nil if an error happened.
		@param aw<Future,Task> The awaitable to wait.
		@returns mixed The awaitable return values, or nil if it had an error.
	]]
	function EventLoop:await_safe(aw)
		self.current_task.stop_error_propagation = true
		return self:await(aw)
	end

	--[[@
		@name add_timeout
		@desc Adds a timeout for an awaitable. Basically it cancels the awaitable once the timeout is reached.
		@param aw<Future,Task> The awaitable to wait.
	]]
	function EventLoop:add_timeout(aw, timeout)
		self.timers:add {
			callback = self.cancel_awaitable,
			when = time() + timeout,
			awaitable = aw
		}
	end

	--[[@
		@name await_for
		@desc A shorthand method for add_timeout and await_safe.
		@param aw<Future,Task> The awaitable to wait
		@param timeout<number> The timeout
		@returns mixed The Future or Task return values.
	]]
	function EventLoop:await_for(aw, timeout)
		self:add_timeout(aw, timeout)
		return self:await_safe(aw)
	end

	--[[@
		@name await_many
		@desc Awaits many awaitables at once. Runs them concurrently, and requires a FutureSemaphore object to do so.
		@param vararg<Future,Task> The awaitables to wait
		@returns FutureSemaphore The FutureSemaphore that will result once every awaitable is done.
	]]
	function EventLoop:await_many(...)
		local length = select("#", ...)
		local semaphore = self:new_object(FutureSemaphore, length)

		local task
		for index = 1, length do
			task = select(index, ...)
			task:add_future(semaphore, index)
			if not task._is_future then
				self:add_task(task)
			end
		end

		return semaphore
	end

	--[[@
		@name run
		@desc Runs a loop iteration.
	]]
	function EventLoop:run()
		self.timers:run()
		self:run_tasks()
		self:remove_tasks()
	end

	function EventLoop:run_until_complete(task)
		local future = self:new_object(Future)
		task:add_future(future)

		self:add_task(task)
		while not future.done do
			self:run()
		end

		return unpack(future.result)
	end

	--[[@
		@name handle_error
		@desc Handles a task error and calls EventLoop:remove_later
		@param task<Task> The task
		@param index<int> The task index in the list, to be removed later.
	]]
	function EventLoop:handle_error(task, index)
		self:remove_later(index)

		task.done = true
		if task.cancelled then
			task.error = "The task was cancelled."
		end

		local future
		for index = 1, task.futures_index do
			future = task.futures[index]
			future.obj:set_error(task.error, true, future.index)
		end

		if task._next_task then
			local _next = task._next_task

			if _next.stop_error_propagation then
				_next.arguments = nil
			else
				_next.error = task.error
				_next.done = true
			end

			self:add_task(_next)
		else
			error(task.error)
		end
	end

	--[[@
		@name remove_later
		@desc Schedules a task removal
		@param index<int> The task to remove
	]]
	function EventLoop:remove_later(index)
		self.removed_index = self.removed_index + 1
		self.removed[self.removed_index] = index
	end

	--[[@
		@name run_tasks
		@desc Runs the tasks in the list only.
	]]
	function EventLoop:run_tasks()
		local tasks, now, task = self.tasks, time()

		for index = 1, self.tasks_index do
			task = tasks[index]

			if not task.cancelled then
				if task.error then
					self:handle_error(task, index)

				else
					self.current_task = task
					task:run(self)

					if task.cancelled or task.error then
						self:handle_error(task, index)
					elseif task.done or task.paused then
						task.paused = false
						self:remove_later(index)
					end
				end
			else
				self:handle_error(task, index)
			end
		end

		self.current_task = nil
	end

	--[[@
		@name remove_tasks
		@desc Removes the tasks that are waiting to be removed from the list.
	]]
	function EventLoop:remove_tasks()
		local tasks, removed, remove = self.tasks, self.removed
		for index = 1, self.removed_index do
			remove = removed[index]

			if remove < self.tasks_index then
				tasks[remove] = tasks[self.tasks_index]
				-- tasks[self.tasks_index] = nil -- uncomment if you want to make #self.tasks and self.tasks_index match
				-- Remember that uncommenting the line won't make the loop respect the tasks order. Use OrderedEventLoop for that.
			end

			self.tasks_index = self.tasks_index - 1
		end

		self.removed_index = 0
	end
end

local OrderedEventLoop
do
	local remove = table.remove

	OrderedEventLoop = setmetatable(
		{}, {__index = EventLoop}
	)
	local meta = {__index = OrderedEventLoop}

	--[[@
		@name new
		@desc Creates a new instance of OrderedEventLoop: the same as EventLoop but respecting the tasks order.
		@desc /!\ This is different from EventLoop since here, tasks_index and the quantity of items of tasks match.
		@desc /!\ EventLoop.removed_index might be lower than the quantity of items in the EventLoop.removed list. You must trust removed_index.
		@desc /!\ The tasks orders is the one they acquire once you run OrderedEventLoop:add_task.
		@param obj?<table> The table to turn into an EventLoop.
		@returns OrderedEventLoop The OrderedEventLoop.
		@struct {
			timers = TimerList, -- A list of the timers the EventLoop will handle
			tasks = {}, -- The list of tasks the EventLoop is running
			removed = {}, -- The list of indexes in the tasks list to remove
			tasks_index = 0, -- The tasks list pointer
			removed_index = 0 -- The removed list pointer
		}
	]]
	function OrderedEventLoop.new(obj)
		return setmetatable(EventLoop.new(obj), meta)
	end

	--[[@
		@name remove_tasks
		@desc Removes the tasks that are waiting to be removed from the list.
	]]
	function OrderedEventLoop:remove_tasks()
		local tasks, removed = self.tasks, self.removed
		for index = self.removed_index, 1, -1 do
			remove(tasks, removed[index])
		end

		self.tasks_index = self.tasks_index - self.removed_index
		self.removed_index = 0
		-- self.removed = {} -- uncomment if you want to make #self.removed and self.removed_index always match
	end
end

local LimitedEventLoop
do
	local time = os.time

	LimitedEventLoop = setmetatable(
		{}, {__index = EventLoop}
	)
	local meta = {__index = LimitedEventLoop}

	--[[@
		@name new
		@desc Creates a new instance of LimitedEventLoop: the same as EventLoop but with runtime limitations
		@desc This inherits from EventLoop
		@param obj<table,nil> The table to turn into an EventLoop.
		@param runtime<int> The maximum runtime that can be used.
		@param reset<int> How many time it needs to wait until the used runtime is resetted.
		@returns LimitedEventLoop The LimitedEventLoop.
		@struct {
			timers = TimerList, -- A list of the timers the EventLoop will handle
			tasks = {}, -- The list of tasks the EventLoop is running
			removed = {}, -- The list of indexes in the tasks list to remove
			tasks_index = 0, -- The tasks list pointer
			removed_index = 0, -- The removed list pointer
			runtime = runtime, -- The maximum runtime
			reset = reset, -- The reset interval
			used = 0, -- The used runtime
			initialized = 0, -- When was the last runtime reset
			step = 0 -- The iteration step (0 -> needs to run timers, 1 -> needs to run tasks, 2 -> needs to remove tasks)
		}
	]]
	function LimitedEventLoop.new(obj, runtime, reset)
		obj = EventLoop.new(obj)
		obj.runtime = runtime
		obj.reset = reset
		obj.used = 0
		obj.initialized = 0
		obj.step = 0
		return setmetatable(obj, meta)
	end

	--[[@
		@name can_run
		@desc Checks if the EventLoop can run something.
		@param now<int> How many runtime is being used and not counted in LimitedEventLoop.used
		@returns boolean Whether it can run something or not
	]]
	function LimitedEventLoop:can_run(now)
		return self.used + now < self.runtime
	end

	--[[@
		@name run
		@desc Runs (or partially runs) a loop iteration if it is possible.
	]]
	function LimitedEventLoop:run()
		local start = time()

		if start - self.initialized >= self.reset then
			self.initialized = start
			self.used = 0
		end

		if self.step == 0 then
			if self:can_run(0) then
				self.timers:run()
				self.step = 1
			end
		end

		if self.step == 1 then
			if self:can_run(time() - start) then
				self:run_tasks()
				self.step = 2
			end
		end

		if self.step == 2 then
			if self:can_run(time() - start) then
				self:remove_tasks()
				self.step = 0
			end
		end

		self.used = self.used + time() - start
	end
end

--[[@
	@name MixedEventLoop
	@desc Creates a new object which is a mix of any EventLoop's variants.
	@param eventloop<table> The table to turn into the mix
	@param vararg<EventLoop> The classes to mix
	@returns EventLoop The mixed event loop.
]]
local function MixedEventLoop(eventloop, ...)
	local classes = {...}
	local length = #classes

	setmetatable(eventloop, {
		__index = function(tbl, key)
			local v
			for i = 1, length do
				v = classes[i][key]
				if v then return v end
			end
		end
	})
	local meta = {__index = eventloop}

	function eventloop.new(obj)
		local obj = obj or {}
		for i = 1, length do
			obj = classes[i].new(obj)
		end

		return setmetatable(obj, meta)
	end

	return eventloop
end

return {
	EventLoop = EventLoop,
	OrderedEventLoop = OrderedEventLoop,
	LimitedEventLoop = LimitedEventLoop,
	MixedEventLoop = MixedEventLoop,
	get_event_loop = get_event_loop
}