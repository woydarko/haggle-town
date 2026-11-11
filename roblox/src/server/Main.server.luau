--!strict
-- Server entry: builds the town, validates every client intent, forwards it to the backend, pushes state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Backend = require(script.Parent.Backend)
local World = require(script.Parent.World)
local Boards = require(script.Parent.Boards)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Validate = require(Shared:WaitForChild("Validate"))

local world = World.build()
Boards.renderPrices(world.priceBoard, nil)
Boards.renderLeaders(world.leaderBoard, nil)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function rf(name: string): RemoteFunction
	local r = Instance.new("RemoteFunction")
	r.Name = name
	r.Parent = remotes
	return r
end
local function re(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local Haggle, Accept, GatherFinish = rf("Haggle"), rf("Accept"), rf("GatherFinish")
local StateChanged, OpenHaggle, Toast, PlayMinigame = re("StateChanged"), re("OpenHaggle"), re("Toast"), re("PlayMinigame")
remotes.Parent = ReplicatedStorage

local issued: { [Player]: { [string]: boolean } } = {}
-- One minigame per player; the session id never leaves the server. `at` lets a stuck session expire with the backend's 60 s TTL.
local gathering: { [Player]: { id: string?, part: BasePart, at: number } } = {}
local SESSION_TTL = 60
local lastState: any = nil

local function uid(p: Player): string
	return tostring(p.UserId)
end

local function distance(p: Player, target: BasePart): number?
	local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return hrp and (hrp.Position - target.Position).Magnitude or nil
end

-- Merchant lines are shaped by what the player typed, so they go through Roblox text filtering.
local function filter(text: string, p: Player): string
	local ok, out = pcall(function()
		return TextService:FilterStringAsync(text, p.UserId):GetNonChatStringForBroadcastAsync()
	end)
	return if ok then out else "..."
end

Players.PlayerAdded:Connect(function(p)
	issued[p] = {}
	local ok, r = Backend.post("/rbx/join", { userId = uid(p), name = p.DisplayName })
	StateChanged:FireClient(p, if ok then { balances = r.balances, board = lastState and lastState.board } else { offline = true })
end)

Players.PlayerRemoving:Connect(function(p)
	issued[p] = nil
	gathering[p] = nil
end)

for node, nodePart in world.nodes do
	local pp = nodePart:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
	pp.Triggered:Connect(function(p)
		if not (Validate.node(node) and Validate.near(distance(p, nodePart))) then
			return
		end
		local open = gathering[p]
		if open and os.clock() - open.at < SESSION_TTL then
			return
		end
		local slot = { id = nil :: string?, part = nodePart, at = os.clock() }
		gathering[p] = slot -- reserved before the yielding HTTP call so a double trigger cannot start two
		local ok, r = Backend.post("/rbx/gather/start", { userId = uid(p), node = node })
		if gathering[p] ~= slot then
			return -- player left meanwhile
		end
		if not ok then
			gathering[p] = nil
			Toast:FireClient(p, "Market offline - your goods are safe")
			return
		end
		slot.id = r.sessionId
		PlayMinigame:FireClient(p, node, r.params)
	end)
end

-- quality nil = the player failed the minigame: close locally, nothing is caught (the backend session just expires).
GatherFinish.OnServerInvoke = function(p: Player, quality: any)
	local s = gathering[p]
	if not (s and s.id) then
		return { error = "no_session" }
	end
	gathering[p] = nil
	if quality == nil then
		return { message = "It got away..." }
	end
	if not Validate.quality(quality) then
		return { error = "invalid" }
	end
	if not Validate.near(distance(p, s.part)) then
		return { message = "You walked away from the spot." }
	end
	local ok, r = Backend.post("/rbx/gather/finish", { userId = uid(p), sessionId = s.id, quality = quality })
	if not ok then
		return { message = if r.error == "too_fast" or r.error == "session_closed" then "It slipped away - try again." else "Market offline - your goods are safe" }
	end
	StateChanged:FireClient(p, { balances = r.balances })
	return { catch = r.catch }
end

for name, body in world.merchants do
	local pp = body:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
	pp.Triggered:Connect(function(p)
		if Validate.near(distance(p, body)) then
			OpenHaggle:FireClient(p, name)
		end
	end)
end

Haggle.OnServerInvoke = function(p: Player, merchant: any, text: any)
	if not (Validate.merchant(merchant) and Validate.text(text)) then
		return { error = "invalid" }
	end
	if not Validate.near(distance(p, world.merchants[merchant])) then
		return { error = "too_far", message = "Walk closer to the stall." }
	end
	local ok, r = Backend.post("/rbx/haggle", { userId = uid(p), merchant = merchant, message = text })
	if not ok then
		return { error = r.error or "offline", message = r.message }
	end
	r.line = filter(r.line, p)
	if r.counter then
		issued[p][r.counter.dealId] = true
	end
	return r
end

Accept.OnServerInvoke = function(p: Player, dealId: any)
	local mine = issued[p] or {}
	if not Validate.deal(mine, dealId) then
		return { status = "failed", reason = "invalid" }
	end
	mine[dealId] = nil
	local ok, r = Backend.post("/rbx/accept", { userId = uid(p), dealId = dealId })
	if not ok then
		return { status = "failed", reason = r.error or "offline" }
	end
	if r.status == "requoted" then
		mine[r.counter.dealId] = true
		r.line = filter(r.line, p)
	end
	if r.balances then
		StateChanged:FireClient(p, { balances = r.balances })
	end
	return r
end

-- One state poll per player every 5 s keeps HUD and boards fresh (well under Roblox's 500 req/min).
task.spawn(function()
	while true do
		task.wait(5)
		for _, p in Players:GetPlayers() do
			task.spawn(function()
				local ok, r = Backend.get("/rbx/state?userId=" .. uid(p))
				if ok then
					lastState = r
					StateChanged:FireClient(p, r)
				else
					StateChanged:FireClient(p, { offline = true })
				end
			end)
		end
		if lastState then
			Boards.renderPrices(world.priceBoard, lastState.board)
			Boards.renderLeaders(world.leaderBoard, lastState.leaderboard)
		end
	end
end)
