local tasks = require "lib/public/asyncio/tasks"
local async = tasks.async

local Lock
do
	Lock = {}
	local meta = {__index = Lock}

	--[[@
		@name new
		@desc Creates a new instance of Lock
		@desc This is an object used to have exclusive access to shared resources.
		@desc If a task acquired it, no other task can acquire the object again until this one releases it
		@param loop<EventLoop> The EventLoop that the Lock belongs to.
		@returns Lock The Lock object
		@struct {
			loop = loop, -- The EventLoop that the Lock belongs to
			tasks = {}, -- The Tasks objects that are waiting to acquire the Lock
			tasks_append = 0, -- The current tasks list "append" pointer
			tasks_give = 0, -- The current tasks list "give" pointer
			is_locked = false -- Whether the lock is set or not
		}
	]]
	function Lock.new(loop, obj)
		obj = obj or {}
		obj.loop = loop
		obj.tasks = {}
		obj.tasks_append = 0
		obj.tasks_give = 0
		return setmetatable(obj, meta)
	end

	--[[@
		@name acquire
		@desc Returns a task that, when awaited, will block until the lock is acquired.
		@returns Task The task
	]]
	Lock.acquire = async(function(self)
		if self.is_locked then
			self.tasks_append = self.tasks_append + 1
			self.tasks[self.tasks_append] = self.loop.current_task
			self.loop:stop_task_execution()
		else
			self.is_locked = true
		end

		self.task = self.loop.current_task._next_task
		-- Basically, current_task = Lock.acquire, and _next_task = the function that awaited it
	end)

	--[[@
		@name release
		@desc Releases the lock and wakes up the next task waiting to acquire it, if any.
	]]
	function Lock:release()
		if not self.is_locked then
			error("Can't release an unlocked lock.", 2)
		elseif self.loop.current_task ~= self.task then
			print(self.loop.current_task, self.task)
			error("Can't release the lock from a different task.", 2)
		end

		local give, task = self.tasks_give
		while give < self.tasks_append do
			give = give + 1
			task = self.tasks[give]
			self.tasks[give] = nil

			if not task.cancelled and not task.done then
				self.loop:add_task(task)
				self.tasks_give = give
				self.task = task.task
				-- Doesn't unlock the object
				return
			end
		end
		self.tasks_give = give

		self.is_locked = false
	end
end

local Event
do
	Event = {}
	local meta = {__index = Event}

	--[[@
		@name new
		@desc Creates a new instance of Event
		@desc This is an object that notifies other tasks when it is set.
		@param loop<EventLoop> The EventLoop that the Event belongs to.
		@returns Event The Event object
		@struct {
			loop = loop, -- The EventLoop that the Event belongs to
			tasks = {}, -- The tasks that are waiting for the Event to be set
			tasks_index = 0, -- The tasks list pointer
			is_set = false -- Whether the event is set or not
		}
	]]
	function Event.new(loop, obj)
		obj = obj or {}
		obj.loop = loop
		obj.tasks = {}
		obj.tasks_index = 0
		return setmetatable(obj, meta)
	end

	--[[@
		@name wait
		@desc Return a task that, when awaited, will block until Event.is_set is true.
		@returns Task The task
	]]
	Event.wait = async(function(self)
		if self.is_set then return end

		self.tasks_index = self.tasks_index + 1
		self.tasks[self.tasks_index] = self.loop.current_task
		self.loop:stop_task_execution()
	end)

	--[[@
		@name set
		@desc Sets the event and releases every Event:wait() task.
	]]
	function Event:set()
		if self.is_set then return end
		self.is_set = true

		for index = 1, self.tasks_index do
			self.loop:add_task(self.tasks[index])
		end
	end

	--[[@
		@name clear
		@desc Clears (unset) the event, making every new Event:wait() task block again.
	]]
	function Event:clear()
		if not self.is_set then return end
		self.is_set = false

		self.tasks_index = 0
		self.tasks = {}
	end
end

return {
	Lock = Lock,
	Event = Event
}