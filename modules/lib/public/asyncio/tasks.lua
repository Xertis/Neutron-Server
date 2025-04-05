local Task
do
	local remove = table.remove
	local create = coroutine.create
	local resume = coroutine.resume
	local status = coroutine.status

	Task = {}
	local meta = {__index = Task}

	--[[@
		@name new
		@desc Creates a new instance of Task: a function that can be run by an EventLoop
		@desc If you await a Task, it will return the raw function returned values.
		@desc /!\ If you safely await it, it might return nil, and you need to check its error manually.
		@param fnc<function> The function that the task will execute. It can have special EventLoop calls like await, sleep, call_soon...
		@param args<table> A table (with no associative members) to set as the arguments. Can have multiple items.
		@param obj?<table> The table to turn into a Task.
		@returns Task The task object.
		@struct {
			arguments = {}, -- The arguments to give the function the next time Task:run is executed.
			coro = coroutine_function, -- The coroutine wrapping the task function.
			futures = {}, -- A list of futures to set the result after the task is done.
			futures_index = 0, -- The futures list pointer
			stop_error_propagation = false, -- Whether to stop the error propagation or not
			error = false or string, -- The error, if any
			done = false, -- Whether the task is done or not
			cancelled = false, -- Whether the task is cancelled or not
			timer = nil or Timer, -- nil if the task is not scheduled, a Timer object otherwise.
			ran_once = false -- Whether the task did run (or at least partially run)
		}
	]]
	function Task.new(fnc, args, obj)
		obj = obj or {}
		obj.arguments = args
		obj.coro = create(fnc)
		obj.futures = {}
		obj.futures_index = 0
		return setmetatable(obj, meta)
	end

	--[[@
		@name cancel
		@desc Cancels the task, and if it is awaiting something, cancels the awaiting object too.
	]]
	function Task:cancel()
		if self.timer then
			self.timer.list:remove(self.timer)
			self.timer.event_loop:add_task(self)
		elseif self.awaiting then
			self.awaiting:cancel()
		end
		self.cancelled = true
	end

	--[[@
		@name run
		@desc Runs the task function
		@param loop<EventLoop> The loop that will run this part of the task
	]]
	function Task:run(loop)
		self.ran_once = true

		local data
		if self.arguments then
			data = {resume(self.coro, unpack(self.arguments))}
			self.arguments = nil
		else
			data = {resume(self.coro)}
		end

		while data[2] == "get_event_loop" do
			data = {resume(self.coro, loop)}
		end

		if not self.cancelled then
			if status(self.coro) == "dead" then
				self.done = true
				if data[1] then
					if self.futures_index > 0 or self._next_task then
						remove(data, 1)
					else
						return
					end

					local future
					for index = 1, self.futures_index do
						future = self.futures[index]
						future.obj:set_result(data, true, future.index)
					end

					if self._next_task then
						self._next_task.arguments = data
						self._next_task.awaiting = nil

						loop:add_task(self._next_task)
					end
				else
					self.error = debug.traceback(self.coro, data[2])
				end
			end
		end
	end

	--[[@
		@name add_future
		@desc Adds a future that will be set after the task runs.
		@param future<Future> The future object. Can be a variant too.
		@param index?<int> The index given to the future object (used only with FutureSemaphore)
	]]
	function Task:add_future(future, index)
		self.futures_index = self.futures_index + 1
		self.futures[self.futures_index] = {obj=future, index=index}
	end
end

--[[@
	@name async
	@desc A decorator function that will create a new task object with the function passed it everytime it is called.
	@param fnc<function> The function
	@returns function The wrapper.
]]
local function async(fnc)
	return function(...)
		return Task.new(fnc, {...}, {})
	end
end

return {
	Task = Task,
	async = async
}