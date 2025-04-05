local TimerList
do
	local time = os.time

	TimerList = {}
	local meta = {__index = TimerList}

	--[[@
		@name new
		@desc Creates a new instance of TimerList.
		@param obj?<table> The table to turn into a TimerList.
		@returns TimerList The new TimerList object.
		@struct {
			last = Timer -- the last timer (the one that must trigger before all the others). Might be nil.
		}
	]]
	function TimerList.new(obj)
		return setmetatable(obj or {}, meta)
	end

	--[[@
		@name add
		@desc Adds a timer to the list.
		@desc `timer.callback` will receive the timer as the unique argument, so you can add more values here
		@param timer<Timer> The timer to add.
		@paramstruct timer {
			callback<function> The callback function.
			when<int> When it will be executed.
		}
		@returns Timer The timer you've added
	]]
	function TimerList:add(timer)
		timer.list = self

		if not self.last then
			self.last = timer
		elseif self.last.when < timer.when then
			-- sorts the timer in descendent order

			local current, last = self.last.previous, self.last
			while current and current.when < timer.when do
				current, last = current.previous, current
			end

			timer.previous, last.previous = current, timer
		else
			timer.previous = self.last
			self.last = timer
		end

		return timer
	end

	--[[@
		@name run
		@desc Runs the timers that need to be run.
	]]
	function TimerList:run()
		local now, current = time(), self.last
		while current and current.when <= now do
			current:callback() -- gives the timer itself to the callback
			current = current.previous
		end
		self.last = current
	end

	--[[@
		@name remove
		@desc Removes a timer from the list.
		@param timer<Timer> The timer to remove.
	]]
	function TimerList:remove(timer)
		if self.last == timer then
			self.last = timer.previous
			return
		end

		local current, last = self.last.previous, self.last
		while current and current ~= timer do
			current, last = current.previous, current
		end

		if current then
			last.previous = timer.previous
		end
	end
end

return {
	TimerList = TimerList
}