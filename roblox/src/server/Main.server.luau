--!strict
-- Server entry: builds the town, validates every client intent, forwards it to the backend, pushes state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Backend = require(script.Parent.Backend)
local World = require(script.Parent.World)
local Boards = require(script.Parent.Boards)
local Lobby = require(script.Parent.Lobby)
local Nodes = require(script.Parent.Nodes)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Validate = require(Shared:WaitForChild("Validate"))
local Tools = require(Shared:WaitForChild("Tools"))

-- Nobody spawns before the big map exists (they would fall through); clients show a loading screen meanwhile.
Players.CharacterAutoLoads = false
workspace:SetAttribute("WorldProgress", 0)
local buildStart = os.clock()
local world = World.build(function(f)
	workspace:SetAttribute("WorldProgress", f)
end)
Nodes.tools()
local counts = Nodes.build()
Nodes.start()
print(string.format("[HaggleTown] map built in %.1f s (%d trees, %d rocks, %d fishing spots)", os.clock() - buildStart, counts.trees, counts.rocks, counts.spots))
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
local gathering: { [Player]: { id: string?, part: BasePart, at: number, n: Nodes.Node } } = {}
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

-- Frees the node a player holds (minigame failed, walked away, died, left).
local function letGo(p: Player)
	local s = gathering[p]
	if s then
		gathering[p] = nil
		Nodes.release(s.n, p)
	end
end

local hinted: { [Player]: number } = {}
local function hint(p: Player, text: string) -- at most one hint every 3 s, swings repeat fast
	if os.clock() - (hinted[p] or 0) > 3 then
		hinted[p] = os.clock()
		Toast:FireClient(p, text)
	end
end

-- Tool swing (server-side Tool.Activated, so the client never names a node): the nearest node of the
-- tool's kind within reach is claimed for this player and its minigame starts.
local function onToolUse(p: Player, toolName: string)
	local info = Tools[toolName]
	local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (info and hrp) then
		return
	end
	local open = gathering[p]
	if open and os.clock() - open.at < SESSION_TTL then
		Nodes.hit(open.n) -- swings during the minigame keep the claim alive
		return
	end
	letGo(p) -- a stuck old session
	local n, d = Nodes.nearest(hrp.Position, info.tag)
	if not (n and Validate.near(d) and Validate.node(n.node)) then
		hint(p, info.noTarget)
		return
	end
	local claimed, why = Nodes.claim(n, p)
	if not claimed then
		hint(p, if why == "taken" then info.taken else info.gone)
		return
	end
	local slot = { id = nil :: string?, part = n.hit, at = os.clock(), n = n }
	gathering[p] = slot -- reserved before the yielding HTTP call so a double swing cannot start two
	local ok, r = Backend.post("/rbx/gather/start", { userId = uid(p), node = n.node })
	if gathering[p] ~= slot then
		Nodes.release(n, p) -- player left or walked off meanwhile
		return
	end
	if not ok then
		letGo(p)
		Toast:FireClient(p, "Market offline - your goods are safe")
		return
	end
	slot.id = r.sessionId
	PlayMinigame:FireClient(p, n.node, r.params)
end

local function hookTools(p: Player)
	local function hook(t: Instance)
		if t:IsA("Tool") and Tools[t.Name] and not t:GetAttribute("Hooked") then
			t:SetAttribute("Hooked", true)
			t.Activated:Connect(function()
				onToolUse(p, t.Name)
			end)
		end
	end
	local bp = p:WaitForChild("Backpack")
	for _, t in bp:GetChildren() do
		hook(t)
	end
	bp.ChildAdded:Connect(hook)
end

-- CharacterAutoLoads is off, so the server spawns and respawns everyone itself.
local function spawnLoop(p: Player)
	p.CharacterAdded:Connect(function(char)
		task.spawn(hookTools, p)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		hum.Died:Connect(function()
			letGo(p)
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
	letGo(p)
	hinted[p] = nil
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

-- Claims follow the player: walking away or a stuck session frees the node within about a second.
task.spawn(function()
	while true do
		task.wait(1)
		for p, slot in gathering do
			local d = distance(p, slot.part)
			if os.clock() - slot.at > SESSION_TTL or not (d and d < 16) then
				letGo(p)
			end
		end
	end
end)

-- quality nil = the player failed the minigame: close locally, nothing is caught (the backend session just expires).
GatherFinish.OnServerInvoke = function(p: Player, quality: any)
	local s = gathering[p]
	if not (s and s.id) then
		return { error = "no_session" }
	end
	gathering[p] = nil -- the node stays claimed until the backend answers, so nobody grabs a tree about to fall
	if quality == nil or not Validate.quality(quality) or not Validate.near(distance(p, s.part)) then
		Nodes.release(s.n, p)
		return if quality == nil
			then { message = "It got away..." }
			elseif not Validate.quality(quality) then { error = "invalid" }
			else { message = "You walked away from the spot." }
	end
	local ok, r = Backend.post("/rbx/gather/finish", { userId = uid(p), sessionId = s.id, quality = quality })
	if not ok then
		Nodes.release(s.n, p)
		return { message = if r.error == "too_fast" or r.error == "session_closed" then "It slipped away - try again." else "Market offline - your goods are safe" }
	end
	if s.n.tag == "GatherWater" then
		Nodes.release(s.n, p)
	else
		Nodes.fell(s.n) -- the tree falls / the rock breaks
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
