local Future
do
	Future = {}
	local meta = {__index = Future}

	--[[@
		@name new
		@desc Creates a new instance of Future: an object that will return later. You can use EventLoop:await on it, but you can't use EventLoop:add_task.
		@desc If you await it, it will return the :set_result() unpacked table. If you set the result to {"a", "b", "c"}, it will return "a", "b", "c".
		@desc /!\ If you safely await it, it will return nil and you need to manually check its error.
		@param loop<EventLoop> The loop that the future belongs to
		@param obj?<table> The table to turn into a Future.
		@returns Future The Future object
		@struct {
			_is_future = true, -- used to denote that it is a Future object
			loop = EventLoop, -- the loop that the future belongs to
			_next_tasks = {}, -- the tasks that the Future is gonna run once it is done
			_next_tasks_index = 0, -- the tasks table pointer
			futures = {}, -- the futures to trigger after this is done
			futures_index = 0, -- the futures pointer
			result = nil or table, -- the Future result; if it is nil, it didn't end yet.
			error = false or string, -- whether the future has thrown an error or not
			cancelled = false, -- whether the future is cancelled or not
			done = false -- whether the future is done or not
		}
	]]
	function Future.new(loop, obj)
		obj = obj or {}
		obj._is_future = true
		obj.loop = loop
		obj._next_tasks = {}
		obj._next_tasks_index = 0
		obj.futures = {}
		obj.futures_index = 0
		return setmetatable(obj, meta)
	end

	--[[@
		@name cancel
		@desc Cancels the Future
	]]
	function Future:cancel()
		self.cancelled = true
	end

	--[[@
		@name add_future
		@desc Adds a future that will be set after this one is done.
		@param future<Future> The future object. Can be a variant too.
		@param index?<int> The index given to the future object (used only with FutureSemaphore)
	]]
	function Future:add_future(future, index)
		self.futures_index = self.futures_index + 1
		self.futures[self.futures_index] = {obj=future, index=index}
	end

	--[[@
		@name set_result
		@desc Sets the Future result and calls all the scheduled tasks
		@param result<table> A table (with no associative members) to set as the result. Can have multiple items.
		@param safe?<boolean> Whether to cancel the error if the result can't be set. @default false.
	]]
	function Future:set_result(result, safe)
		if self.done then
			local msg = "The Future has already been done."
			if safe then return msg
			else error(msg, 2) end
		elseif self.cancelled then
			local msg = "The Future was cancelled."
			if safe then return msg
			else error(msg, 2) end
		end

		self.done = true
		self.result = result

		local future
		for index = 1, self.futures_index do
			future = self.futures[index]
			future.obj:set_result(result, true, future.index)
		end

		local task
		for index = 1, self._next_tasks_index do
			task = self._next_tasks[index]
			task.arguments = result
			task.awaiting = nil
			self.loop:add_task(task)
		end
	end

	--[[@
		@name set_error
		@desc Sets the Future error and calls all the scheduled tasks
		@param result<string> A string to set as the error message.
		@param safe?<boolean> Whether to cancel the error if the result can't be set. @default false.
	]]
	function Future:set_error(result, index, safe)
		if self.done then
			local msg = "The Future has already been done."
			if safe then return msg
			else error(msg, 2) end
		elseif self.cancelled then
			local msg = "The Future was cancelled."
			if safe then return msg
			else error(msg, 2) end
		end
		result = debug.traceback(result, 2)

		self.error = result
		self.done = true

		local future
		for index = 1, self.futures_index do
			future = self.futures[index]
			future.obj:set_error(result, true, future.index)
		end

		local task
		for index = 1, self._next_tasks_index do
			task = self._next_tasks[index]

			if task.stop_error_propagation then
				task.arguments = nil
			else
				task.error = result
				task.done = true
			end

			task.awaiting = nil
			self.loop:add_task(task)
		end
	end
end

local FutureSemaphore
do
	FutureSemaphore = setmetatable(
		{}, {__index=Future}
	)
	local meta = {__index = FutureSemaphore}

	--[[@
		@name new
		@desc Creates a new instance of FutureSemaphore: an object that will return many times later. This inherits from Future.
		@desc You can use EventLoop:await on it, but you can't use add_task.
		@desc If you await it, it will return a table where you can get all the appended values with their respective indexes.
		@desc /!\ FutureSemaphore will never propagate an error, instead, it will append it to the result as a string.
		@param loop<EventLoop> The loop that the future belongs to
		@param quantity<int> The quantity of values that the object will return.
		@param obj?<table> The table to turn into a FutureSemaphore.
		@returns FutureSemaphore The FutureSemaphore object
		@struct {
			_is_future = true, -- used to denote that it is a Future object
			loop = EventLoop, -- the loop that the future belongs to
			quantity = quantity, -- the quantity of values that the object will return
			_done = 0, -- the quantity of values that the object has prepared
			_next_tasks = {}, -- the tasks that the future is gonna run once it is done
			_next_tasks_index = 0, -- the tasks table pointer
			result = nil or table, -- the Future result; if it is nil, the future is not completely done.
			_result = table -- the FutureSemaphore partial or complete result; if it is nil, no result was given in.
			cancelled = false -- whether the future is cancelled or not
			cancelled = false, -- whether the future is cancelled or not
			done = false -- whether the future is done or not
		}
	]]
	function FutureSemaphore.new(loop, quantity, obj)
		obj = Future.new(loop, obj)
		obj.quantity = quantity
		obj._done = 0
		obj._result = {}
		return setmetatable(obj, meta)
	end

	--[[@
		@name set_result
		@desc Sets a FutureSemaphore result and calls all the scheduled tasks if it is completely done
		@param result<table> A table (with no associative members) to set as the result. Can have multiple items.
		@param safe<boolean> Whether to cancel the error if the result can't be set.
		@param index<number> The index of the result. Can't be repeated.
	]]
	function FutureSemaphore:set_result(result, safe, index)
		if self.done then
			local msg = "The FutureSemaphore has already been done."
			if safe then return msg
			else error(msg, 2) end
		elseif self.cancelled then
			local msg = "The FutureSemaphore was cancelled."
			if safe then return msg
			else error(msg, 2) end
		end

		if not self._result[index] then
			self._result[index] = result
			self._done = self._done + 1
		else
			local msg = "The given semaphore spot is already taken."
			if safe then return msg
			else error(msg, 2) end
		end

		if self._done == self.quantity then
			self.done = true
			self.result = self._result

			local future
			for index = 1, self.futures_index do
				future = self.futures[index]
				future.obj:set_result(self.result, true, future.index)
			end

			local task_result, task = {self.result}
			for _index = 1, self._next_tasks_index do
				task = self._next_tasks[_index]
				task.arguments = task_result
				task.awaiting = nil
				self.loop:add_task(task)
			end
		end
	end

	--[[@
		@name set_error
		@desc Sets a FutureSemaphore error and calls all the scheduled tasks if it is completely done
		@param result<string> A string to set as the error message.
		@param safe<boolean> Whether to cancel the error if the result can't be set.
		@param index<number> The index of the result. Can't be repeated.
	]]
	function FutureSemaphore:set_error(result, safe, index)
		result = debug.traceback(result, 2)
		return self:set_result(result, safe, index)
		-- The behaviour is the same on this future variation
	end
end

return {
	Future = Future,
	FutureSemaphore = FutureSemaphore
}