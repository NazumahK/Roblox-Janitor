--!native
--!optimize 2
--!strict

local FreeThreads: { thread } = table.create(256)

local function RunCallback<Arguments...>(callback: (Arguments...) -> (), thread: thread, ...: Arguments...)
	callback(...)
	table.insert(FreeThreads, thread)
end

local function Yield()
	while true do
		RunCallback(coroutine.yield())
	end
end

local function FastDefer<Arguments...>(callback: (Arguments...) -> (), ...: Arguments...): thread
	local thread: thread
	local freeCount = #FreeThreads

	if freeCount > 0 then
		thread = FreeThreads[freeCount]
		FreeThreads[freeCount] = nil
	else
		thread = coroutine.create(Yield)
		coroutine.resume(thread)
	end

	return task.defer(thread, callback, thread, ...)
end

return FastDefer
