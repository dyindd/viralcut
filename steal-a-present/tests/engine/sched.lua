-- Virtual-time cooperative scheduler: implements task.*, os.time/os.clock, tick, wait and
-- a Heartbeat hook. Tests drive time with Sched.advance(seconds).

Sched = { now = 0, epoch = 1761700000, queue = {}, seq = 0, errors = {}, heartbeat = nil, cancelled = {} }

local function pack(...) return { n = select("#", ...), ... } end

function Sched.schedule(co, t, ...)
	Sched.seq = Sched.seq + 1
	table.insert(Sched.queue, { t = t, seq = Sched.seq, co = co, args = pack(...) })
end

function Sched.resume(co, ...)
	if coroutine.status(co) ~= "suspended" then return end
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		local msg = debug.traceback(co, tostring(err))
		table.insert(Sched.errors, msg)
		io.stderr:write("[ENGINE ERROR] " .. msg .. "\n")
	end
end

local function makeCo(f) return type(f) == "thread" and f or coroutine.create(f) end

task = {}
function task.spawn(f, ...) local co = makeCo(f) Sched.resume(co, ...) return co end
function task.defer(f, ...) local co = makeCo(f) Sched.schedule(co, Sched.now, ...) return co end
function task.delay(t, f, ...) local co = makeCo(f) Sched.schedule(co, Sched.now + (t or 0), ...) return co end
function task.wait(t)
	local co, main = coroutine.running()
	if main then error("task.wait called on the main thread: run this code inside task.spawn or use Sched.advance") end
	local start = Sched.now
	Sched.schedule(co, Sched.now + (t or 1 / 30))
	coroutine.yield()
	return Sched.now - start
end
function task.cancel(co) Sched.cancelled[co] = true end
function task.synchronize() end
function task.desynchronize() end
wait = task.wait
spawn = function(f) task.defer(f) end
delay = function(t, f) task.delay(t, f) end

local realTime = os.time
os.time = function(t) if t then return realTime(t) end return Sched.epoch + math.floor(Sched.now) end
os.clock = function() return Sched.now end
tick = function() return Sched.epoch + Sched.now end
time = function() return Sched.now end
elapsedTime = time

-- run everything due at or before `now`
local function drain()
	local guard = 0
	while true do
		local best, bi
		for i, item in ipairs(Sched.queue) do
			if item.t <= Sched.now + 1e-9 and (not best or item.t < best.t or (item.t == best.t and item.seq < best.seq)) then
				best, bi = item, i
			end
		end
		if not best then return end
		table.remove(Sched.queue, bi)
		if not Sched.cancelled[best.co] then
			Sched.resume(best.co, table.unpack(best.args, 1, best.args.n))
		end
		guard = guard + 1
		if guard > 20000 then error("scheduler runaway: 20000 resumes in one step") end
	end
end

function Sched.step(dt)
	Sched.now = Sched.now + dt
	drain()
	if Sched.heartbeat then Sched.heartbeat:Fire(dt) end
	drain()
end

-- advance virtual time; dt is the simulated frame length (default 0.1s)
function Sched.advance(seconds, dt)
	dt = dt or 0.1
	local steps = math.max(1, math.ceil(seconds / dt - 1e-9))
	for _ = 1, steps do Sched.step(dt) end
end

-- jump the wall clock (os.time) without simulating frames: for day/streak tests
function Sched.skipTime(seconds)
	Sched.epoch = Sched.epoch + seconds
end

function Sched.clearErrors() local e = Sched.errors Sched.errors = {} return e end
