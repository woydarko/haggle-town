--!strict
-- Server entry: builds the town, validates every client intent, forwards it to the backend, pushes state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Backend = require(script.Parent.Backend)
local World = require(script.Parent.World)
local Boards = require(script.Parent.Boards)
local Lobby = require(script.Parent.Lobby)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Validate = require(Shared:WaitForChild("Validate"))

-- Nobody spawns before the big map exists (they would fall through); clients show a loading screen meanwhile.
Players.CharacterAutoLoads = false
workspace:SetAttribute("WorldProgress", 0)
local buildStart = os.clock()
local world = World.build(function(f)
	workspace:SetAttribute("WorldProgress", f)
end)
print(string.format("[HaggleTown] map built in %.1f s", os.clock() - buildStart))
Boards.renderPrices(world.priceBoard, nil)
Boards.renderLeaders(world.leaderBoard, nil)
local lobby = Lobby.build()
Boards.renderLeaders(lobby.leaderBoard, nil)

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
local ChooseClass, GetStats = rf("ChooseClass"), rf("GetStats")
local StateChanged, OpenHaggle, Toast, PlayMinigame = re("StateChanged"), re("OpenHaggle"), re("Toast"), re("PlayMinigame")
local OpenClassCard = re("OpenClassCard")
remotes.Parent = ReplicatedStorage

local issued: { [Player]: { [string]: boolean } } = {}
-- One minigame per player; the session id never leaves the server. `at` lets a stuck session expire with the backend's 60 s TTL.
local gathering: { [Player]: { id: string?, part: BasePart, at: number } } = {}
local SESSION_TTL = 60
local lastState: any = nil
local statsCache: { [Player]: { at: number, value: any } } = {}
local STATS_EVERY = 2 -- seconds; Tab spam must not burn the 500 req/min HTTP budget

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

-- CharacterAutoLoads is off, so the server spawns and respawns everyone itself.
local function spawnLoop(p: Player)
	p.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		hum.Died:Connect(function()
			task.wait(Players.RespawnTime)
			if p.Parent then
				p:LoadCharacter()
			end
		end)
	end)
	p:LoadCharacter()
end

local function onJoin(p: Player)
	issued[p] = {}
	task.spawn(spawnLoop, p)
	local ok, r = Backend.post("/rbx/join", { userId = uid(p), name = p.DisplayName })
	StateChanged:FireClient(p, if ok then { balances = r.balances, class = r.class, board = lastState and lastState.board } else { offline = true })
	if ok and r.class == nil then
		Toast:FireClient(p, "Talk to a mentor in the lobby to pick a class")
	end
end
Players.PlayerAdded:Connect(onJoin)
for _, p in Players:GetPlayers() do -- joined while the map was building
	task.spawn(onJoin, p)
end

Players.PlayerRemoving:Connect(function(p)
	issued[p] = nil
	gathering[p] = nil
	statsCache[p] = nil
end)

for cls, mentor in lobby.mentors do
	local pp = mentor:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
	pp.Triggered:Connect(function(p)
		if Validate.near(distance(p, mentor)) then
			OpenClassCard:FireClient(p, cls)
		end
	end)
end

ChooseClass.OnServerInvoke = function(p: Player, cls: any)
	if not Validate.class(cls) then
		return { error = "invalid" }
	end
	if not Validate.near(distance(p, lobby.mentors[cls])) then
		return { error = "too_far", message = "Walk closer to the mentor." }
	end
	local ok, r = Backend.post("/rbx/class", { userId = uid(p), class = cls })
	if not ok then
		return { error = r.error or "offline", message = r.message or "Market offline - try again soon." }
	end
	statsCache[p] = nil
	StateChanged:FireClient(p, { balances = r.balances, class = r.class })
	return { class = r.class, fee = r.fee }
end

GetStats.OnServerInvoke = function(p: Player)
	local c = statsCache[p]
	if c and os.clock() - c.at < STATS_EVERY then
		return c.value
	end
	local ok, r = Backend.get("/rbx/stats?userId=" .. uid(p))
	if not ok then
		return { error = "offline" }
	end
	statsCache[p] = { at = os.clock(), value = r }
	return r
end

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
			Boards.renderLeaders(lobby.leaderBoard, lastState.leaderboard)
		end
	end
end)
