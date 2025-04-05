local tasks = require "lib/public/asyncio/tasks"
local async = tasks.async

local Queue
do
	Queue = {}
	local meta = {__index = Queue}

	--[[@
		@name new
		@desc Creates a new instance of Queue
		@desc This is a FIFO Queue (first in, first out). If maxsize is less than or equal to zero, the queue size is infinite.
		@desc /!\ Queue.size might be an approximated value some times (on purpose for internal reasons). Use Queue.real_size if you want to get the real queue size.
		@param loop<EventLoop> The EventLoop the Queue belongs to
		@param maxsize?<int> The queue max size. @default 0
		@param obj?<table> The table to turn into a Queue.
		@returns Queue The Queue object
		@struct {
			loop = loop, -- The EventLoop the Queue belongs to
			maxsize = maxsize, -- The queue max size
			waiting_free = {}, -- The sleeping tasks that are waiting for a free spot in the queue
			waiting_free_append = 0, -- The "waiting_free append pointer"
			waiting_free_give = 0, -- The "waiting_free give pointer"
			waiting_item = {}, -- The sleeping tasks that are waiting for an item in the queue
			waiting_item_append = 0, -- The "waiting_item append pointer"
			waiting_item_give = 0, -- The "waiting_item give pointer"
			size = 0, -- The queue approximated size (±1)
			real_size = 0 -- The queue real size
		}
	]]
	function Queue.new(loop, maxsize, obj)
		obj = obj or {}
		obj.loop = loop
		obj.maxsize = maxsize or 0

		obj.waiting_free = {}
		obj.waiting_free_append = 0
		obj.waiting_free_give = 0

		obj.waiting_item = {}
		obj.waiting_item_append = 0
		obj.waiting_item_give = 0

		obj.size = 0
		obj.real_size = 0
		return setmetatable(obj, meta)
	end

	--[[@
		@name full
		@desc Checks if the queue is full or not
		@returns boolean Whether the queue is full or not
	]]
	function Queue:full()
		return self.maxsize > 0 and self.size >= self.maxsize
	end

	--[[@
		@name empty
		@desc Checks if the queue is empty or not
		@returns boolean Whether the queue is empty or not
	]]
	function Queue:empty()
		return self.size == 0
	end

	--[[@
		@name trigger_add
		@desc Wakes up a Queue:get task that is waiting for an item to be added.
		@desc /!\ This method should never be called by the user code.
		@returns boolean Whether a task was triggered or not
	]]
	function Queue:trigger_add()
		local ret, give, task = false, self.waiting_item_give
		while give < self.waiting_item_append do
			give = give + 1
			task = self.waiting_item[give]
			self.waiting_item[give] = nil

			if not task.cancelled and not task.done then
				self.loop:add_task(task)
				ret = true
				break
			end
		end
		self.waiting_item_give = give
		return ret
	end

	--[[@
		@name trigger_remove
		@desc Wakes up a Queue:add task that is waiting for an item to be removed.
		@desc /!\ This method should never be called by the user code.
		@returns boolean Whether a task was triggered or not
	]]
	function Queue:trigger_remove()
		local ret, give, task = false, self.waiting_free_give
		while give < self.waiting_free_append do
			give = give + 1
			task = self.waiting_free[give]
			self.waiting_free[give] = nil

			if not task.cancelled and not task.done then
				self.loop:add_task(task)
				ret = true
				break
			end
		end
		self.waiting_free_give = give
		return ret
	end

	--[[@
		@name add_nowait
		@desc Adds an item to the queue without blocking.
		@param item<table> The item to add
		@param safe?<boolean> Whether to cancel throwing an error if the queue is full @default false
		@returns boolean Whether the item was added or not (if safe is false, this will always be true)
	]]
	function Queue:add_nowait(item, safe)
		if self:full() then
			if safe then
				return false
			end
			error("Can't add an item to a full queue", 2)
		end
		self.real_size = self.real_size + 1

		if not self.first then
			self.first, self.last = item, item
		else
			self.last.next, self.last = item, item
		end

		-- This is where the approximate comes from.
		-- If we add 1 AND trigger a :get, we've got the risk that if the next task
		-- is a new :get, both will be executed, when we can only execute one
		-- (since the queue has only one item because the trigger was successfull,
		-- meaning that it was empty and a :get was waiting an item.)
		-- Solution? Make both tasks (:add and the triggered :get) not increment/decrement
		-- the counter used to get :full() and :empty(). But we've got another problem here:
		-- If the user gets .size between both tasks, it will not be the real size, it will
		-- be a future size. So we add real_size.
		if not self:trigger_add() then
			self.size = self.size + 1
		end
		return true
	end

	--[[@
		@name add
		@desc Returns a task that, when awaited, will try to add the item to the queue, and if it cant, it will block until it can.
		@param item<table> The item to add
		@returns Task The task.
	]]
	Queue.add = async(function(self, item)
		local was_waiting
		if self:full() then
			was_waiting = true
			self.waiting_free_append = self.waiting_free_append + 1
			self.waiting_free[self.waiting_free_append] = self.loop.current_task
			self.loop:stop_task_execution()
		end
		self.real_size = self.real_size + 1

		if not self.first then
			self.first, self.last = item, item
		else
			self.last.next, self.last = item, item
		end

		if not was_waiting and not self:trigger_add() then
			self.size = self.size + 1
		end
	end)

	--[[@
		@name get_nowait
		@desc Gets an item from the queue without blocking.
		@param safe?<boolean> Whether to cancel throwing an error if the queue is empty @default false
		@returns boolean,table `false` if the queue is empty and `safe` is `false`, the item (`table`) otherwise.
	]]
	function Queue:get_nowait(safe)
		if self:empty() then
			if safe then
				return false
			end
			error("Can't get an item from an empty queue", 2)
		end
		self.real_size = self.real_size - 1

		item, self.first = self.first, self.first.next
		item.next = nil

		if not self.first then
			self.last = nil
		end

		if not self:trigger_remove() then
			self.size = self.size - 1
		end
		return item
	end

	--[[@
		@name get
		@desc Returns a task that, when awaited, will try to get an item from the queue, and if it cant, it will block until it can.
		@desc The task always returns a `table`, which is the item.
		@returns Task The task
	]]
	Queue.get = async(function(self)
		local was_waiting
		if self:empty() then
			was_waiting = true
			self.waiting_item_append = self.waiting_item_append + 1
			self.waiting_item[self.waiting_item_append] = self.loop.current_task
			self.loop:stop_task_execution()
		end
		self.real_size = self.real_size - 1

		item, self.first = self.first, self.first.next
		item.next = nil

		if not self.first then
			self.last = nil
		end

		if not was_waiting and not self:trigger_remove() then
			self.size = self.size - 1
		end
		return item
	end)
end

local LifoQueue
do
	LifoQueue = setmetatable(
		{}, {__index = Queue}
	)
	local meta = {__index = LifoQueue}

	--[[@
		@name new
		@desc Creates a new instance of LifoQueue (which inherits from Queue)
		@desc This is a LIFO Queue (last in, first out). If maxsize is less than or equal to zero, the queue size is infinite.
		@desc /!\ Queue.size might be an approximated value some times (on purpose for internal reasons). Use Queue.real_size if you want to get the real queue size.
		@param loop<EventLoop> The EventLoop the Queue belongs to
		@param maxsize?<int> The queue max size. @default 0
		@param obj?<table> The table to turn into a Queue.
		@returns Queue The Queue object
		@struct {
			loop = loop, -- The EventLoop the Queue belongs to
			maxsize = maxsize, -- The queue max size
			waiting_free = {}, -- The sleeping tasks that are waiting for a free spot in the queue
			waiting_free_append = 0, -- The "waiting_free append pointer"
			waiting_free_give = 0, -- The "waiting_free give pointer"
			waiting_item = {}, -- The sleeping tasks that are waiting for an item in the queue
			waiting_item_append = 0, -- The "waiting_item append pointer"
			waiting_item_give = 0, -- The "waiting_item give pointer"
			size = 0, -- The queue approximated size (±1)
			real_size = 0 -- The queue real size
		}
	]]
	function LifoQueue.new(loop, maxsize, obj)
		return setmetatable(Queue.new(loop, maxsize, obj or {}), meta)
	end

	--[[@
		@name add_nowait
		@desc Adds an item to the queue without blocking.
		@param item<QueueItem> The item to add
		@param safe?<boolean> Whether to cancel throwing an error if the queue is full @default false
		@returns boolean Whether the item was added or not (if safe is false, this will always be true)
	]]
	function LifoQueue:add_nowait(item, safe)
		if self:full() then
			if safe then
				return false
			end
			error("Can't add an item to a full queue", 2)
		end
		self.real_size = self.real_size + 1

		if not self.first then
			self.first, self.last = item, item
		else
			item.next, self.first = self.first, item
		end

		if not self:trigger_add() then
			self.size = self.size + 1
		end
		return true
	end

	--[[@
		@name add
		@desc Returns a task that, when awaited, will try to add the item to the queue, and if it cant, it will block until then.
		@param item<QueueItem> The item to add
		@returns Task The task.
	]]
	LifoQueue.add = async(function(self, item)
		local was_waiting
		if self:full() then
			was_waiting = true
			self.waiting_free_append = self.waiting_free_append + 1
			self.waiting_free[self.waiting_free_append] = self.loop.current_task
			self.loop:stop_task_execution()
		end
		self.real_size = self.real_size + 1

		if not self.first then
			self.first, self.last = item, item
		else
			item.next, self.first = self.first, item
		end

		if not was_waiting and not self:trigger_add() then
			self.size = self.size + 1
		end
	end)
end

return {
	Queue = Queue,
	LifoQueue = LifoQueue
}