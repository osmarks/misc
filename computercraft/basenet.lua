local channel = settings.get "basenet.channel" or 23032
local modem = peripheral.find "modem"
if not modem then error "modem required" end
modem.open(channel)
local name = settings.get "basenet.name" or _G.basenet_name or error "name required"

local basenet = {
	listening_to = {},
	tasks = {}
}

function basenet.listen(fn, from)
	if type(from) ~= "string" then error "from must be a string" end
	basenet.listening_to[from] = true
	basenet.run_task(function()
		while true do
			local _, ufrom, data = os.pullEvent "update"
			if ufrom == from then
				fn(data)
			end
		end
	end)
end

function basenet.update(data)
	modem.transmit(channel, channel, { type = "update", from = name, data = data })
end

local task_ID = 0
function basenet.run_task(fn, ...)
	local args = {...}
	task_ID = task_ID + 1
	basenet.tasks[task_ID] = { coroutine = coroutine.create(fn), init_args = args, ID = task_ID }
	os.queueEvent "dummy"
	return task_ID
end

function basenet.interval(fn, time)
	if not time then error "time required" end
	basenet.run_task(function()
		while true do
			fn()
			sleep(time)
		end
	end)
end

local function process_message(msg)
	if msg.type == "update" and type(msg.from) == "string" then
		if basenet.listening_to[msg.from] then
			os.queueEvent("update", msg.from, msg.data)
		end
	end
end

basenet.run_task(function()
	while true do
		local _, _, c, rc, msg, distance = os.pullEvent "modem_message"
		if c == channel and type(msg) == "table" then
			process_message(msg)
		end
	end
end)

local function tick_task(task, evt)
	if task.init_args then
		local init = task.init_args
		task.init_args = nil
		local ok = tick_task(task, init)
		if not ok then return end
	end
	if coroutine.status(task.coroutine) == "dead" then
		basenet.tasks[task.ID] = nil
	else
		if task.filter == nil or task.filter == evt[1] then
			local ok, result = coroutine.resume(task.coroutine, unpack(evt))
			if ok then
				task.filter = result
			else
				printError(("TASK %d ERROR: %s"):format(task.ID, result))
				basenet.tasks[task.ID] = nil
			end
			return ok
		end
	end
end

function basenet.run()
	while true do
		local evt = {os.pullEvent()}
		for ID, task in pairs(basenet.tasks) do
			tick_task(task, evt)
		end
	end
end

return basenet