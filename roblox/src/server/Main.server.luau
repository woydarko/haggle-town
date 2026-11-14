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
local Regions = require(Shared:WaitForChild("Regions"))

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
local ledger = require(script.Parent.Ledger).start()
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
local CastAt = rf("CastAt")
local ChooseClass, GetStats = rf("ChooseClass"), rf("GetStats")
local ForgeRF = rf("Forge")
local BuyToolRF = rf("BuyTool")
-- Market Ledger pop-up: the latest public market view (prices, recent deals, top traders); no player data.
rf("GetLedger").OnServerInvoke = function()
	return ledger.latest()
end
local StateChanged, OpenHaggle, Toast, PlayMinigame = re("StateChanged"), re("OpenHaggle"), re("Toast"), re("PlayMinigame")
local OpenClassCard = re("OpenClassCard")
local GatherFx = re("GatherFx")
remotes.Parent = ReplicatedStorage

local issued: { [Player]: { [string]: boolean } } = {}
-- One minigame per player; the session id never leaves the server. `at` lets a stuck session expire with the backend's 60 s TTL.
-- pos/reach: where the gathering happens and how far the player may stand (12 at a tree/rock, 45 to a bobber).
-- n: the claimed tree/rock (nil when fishing: open water has no node to claim).
type Slot = { id: string?, pos: Vector3, reach: number, at: number, n: Nodes.Node? }
local gathering: { [Player]: Slot } = {}
local CAST_REACH = 45
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

-- Is the player still within reach of their gathering spot?
local function inReach(p: Player, s: Slot, slack: number): boolean
	local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return hrp ~= nil and (hrp.Position - s.pos).Magnitude <= s.reach + slack
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
		if s.n then
			Nodes.release(s.n, p)
		end
	end
end

local hinted: { [Player]: number } = {}
local lastForge: { [Player]: number } = {} -- Forge rate limit
local lastFx: { [Player]: number } = {} -- GatherFx rate limit
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
	if toolName == "Rod" then
		return -- fishing starts from the client's cast (CastAt below), where the bobber lands
	end
	local open = gathering[p]
	if open and os.clock() - open.at < SESSION_TTL then
		if open.n then
			Nodes.hit(open.n) -- swings during the minigame keep the claim alive
		end
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
	local slot: Slot = { id = nil, pos = n.hit.Position, reach = 12, at = os.clock(), n = n }
	gathering[p] = slot -- reserved before the yielding HTTP call so a double swing cannot start two
	local ok, r = Backend.post("/rbx/gather/start", { userId = uid(p), node = n.node })
	if gathering[p] ~= slot then
		Nodes.release(n, p) -- player left or walked off meanwhile
		return
	end
	if not ok then
		letGo(p)
		Toast:FireClient(p, if r.error == "no_tool" then r.message else "Market offline - your goods are safe")
		return
	end
	slot.id = r.sessionId
	PlayMinigame:FireClient(p, n.node, r.params, n.id)
end

-- Forge level on the tools: a copper (Sturdy) or gold (Master) outline and the tool's name in its tooltip.
local toolLevels: { [Player]: { [string]: any } } = {}
local GLOW = { [2] = Color3.fromHex("C86A34"), [3] = Color3.fromHex("F3C232") }
local TOOL_NAME = { axe = "Axe", pickaxe = "Pickaxe", rod = "Rod" }
local function applyLook(p: Player, t: Instance)
	local info = if t:IsA("Tool") then Tools[t.Name] else nil
	local v = info and toolLevels[p] and toolLevels[p][t.Name]
	if not (info and v) then
		return
	end
	(t :: Tool).ToolTip = `{v.name} - {info.tip}`
	local glow = t:FindFirstChild("ForgeGlow") :: Highlight?
	local color = GLOW[v.level]
	if not color then
		if glow then
			glow:Destroy()
		end
		return
	end
	local g = glow or Instance.new("Highlight")
	g.Name = "ForgeGlow"
	g.FillColor, g.OutlineColor = color, color
	g.FillTransparency, g.OutlineTransparency = 0.8, 0.1
	g.DepthMode = Enum.HighlightDepthMode.Occluded
	g.Parent = t
end
-- Owned tools in the Backpack (bought or granted ones appear, the trade's tool first since it comes first).
local function giveTools(p: Player)
	local owned = toolLevels[p]
	local bp = p:FindFirstChild("Backpack")
	local templates = game:GetService("ServerStorage"):FindFirstChild("ToolTemplates")
	if not (owned and bp and templates and p.Character) then
		return
	end
	for _, name in { "Axe", "Pickaxe", "Rod" } do
		local v = owned[name]
		local has = bp:FindFirstChild(name) or (p.Character :: Model):FindFirstChild(name)
		if v and v.owned ~= false and not has then
			local t = templates:FindFirstChild(name)
			if t then
				t:Clone().Parent = bp
			end
		elseif v and v.owned == false and has then
			has:Destroy()
		end
	end
end

local function setForge(p: Player, forge: any)
	if type(forge) ~= "table" then
		return
	end
	local byTool = {}
	for _, v in forge do
		if type(v) == "table" and TOOL_NAME[v.tool] then
			byTool[TOOL_NAME[v.tool]] = v
		end
	end
	toolLevels[p] = byTool
	giveTools(p)
	for _, holder in { p:FindFirstChild("Backpack"), p.Character } do
		if holder then
			for _, t in holder:GetChildren() do
				applyLook(p, t)
			end
		end
	end
end

local function hookTools(p: Player)
	local function hook(t: Instance)
		applyLook(p, t)
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
	giveTools(p) -- a fresh Backpack after a respawn
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
	if ok then
		setForge(p, r.forge)
	end
	StateChanged:FireClient(p, if ok then { balances = r.balances, class = r.class, board = lastState and lastState.board, forge = r.forge } else { offline = true })
	if ok and r.class == nil then
		Toast:FireClient(p, "Talk to the mentor in the guild yard to pick a trade")
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
	lastFx[p] = nil
	statsCache[p] = nil
	toolLevels[p] = nil
	lastForge[p] = nil
end)

-- One guild mentor: the prompt opens the class conversation (ClassCard) where the player picks a trade.
local mentorPrompt = lobby.mentor:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
mentorPrompt.Triggered:Connect(function(p)
	if Validate.near(distance(p, lobby.mentor)) then
		OpenClassCard:FireClient(p)
	end
end)

ChooseClass.OnServerInvoke = function(p: Player, cls: any)
	if not Validate.class(cls) then
		return { error = "invalid" }
	end
	if not Validate.near(distance(p, lobby.mentor)) then
		return { error = "too_far", message = "Walk closer to the mentor." }
	end
	local ok, r = Backend.post("/rbx/class", { userId = uid(p), class = cls })
	if not ok then
		return { error = r.error or "offline", message = r.message or "Market offline - try again soon." }
	end
	statsCache[p] = nil
	setForge(p, r.forge) -- picking a trade hands over its tool
	StateChanged:FireClient(p, { balances = r.balances, class = r.class, forge = r.forge })
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
			if os.clock() - slot.at > SESSION_TTL or not inReach(p, slot, 4) then
				letGo(p)
			end
		end
	end
end)

-- Minigame swing results (good / perfect / miss) shown to everyone nearby through node attributes.
-- Cosmetic only: the catch still comes from the backend; capped at ~6 per second per player.
local FX_KINDS = { good = true, perfect = true, miss = true }
GatherFx.OnServerEvent:Connect(function(p: Player, kind: any)
	local s = gathering[p]
	if not (s and s.id and FX_KINDS[kind]) or os.clock() - (lastFx[p] or 0) < 0.15 then
		return
	end
	lastFx[p] = os.clock()
	local n = s.n
	if n then
		Nodes.hit(n)
		n.model:SetAttribute("HitKind", kind)
		n.model:SetAttribute("Hit", ((n.model:GetAttribute("Hit") :: number?) or 0) + 1)
	end
end)

-- Fishing: the client casts the bobber and sends where it landed; the server re-checks that it is fishable water
-- within reach (Regions.castNode), picks lake (fish) or sea (fish_deep), and opens the backend session.
CastAt.OnServerInvoke = function(p: Player, point: any)
	local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if typeof(point) ~= "Vector3" or not hrp then
		return { message = "Cast into the water" }
	end
	local open = gathering[p]
	if open and os.clock() - open.at < SESSION_TTL then
		return { message = "Finish what you are doing first" }
	end
	letGo(p)
	local node, why = Regions.castNode(hrp.Position.X, hrp.Position.Z, point.X, point.Z, CAST_REACH)
	if not (node and Validate.node(node)) then
		return { message = if why == "far" then "Too far - cast closer" else "Cast into the water" }
	end
	local slot: Slot = { id = nil, pos = Vector3.new(point.X, hrp.Position.Y, point.Z), reach = CAST_REACH, at = os.clock() }
	gathering[p] = slot
	local ok, r = Backend.post("/rbx/gather/start", { userId = uid(p), node = node })
	if gathering[p] ~= slot then
		return { message = "It got away..." }
	end
	if not ok then
		gathering[p] = nil
		return { message = if r.error == "no_tool" then r.message else "Market offline - your goods are safe" }
	end
	slot.id = r.sessionId
	return { node = node, params = r.params }
end

-- quality nil = the player failed the minigame: close locally, nothing is caught (the backend session just expires).
GatherFinish.OnServerInvoke = function(p: Player, quality: any)
	local s = gathering[p]
	if not (s and s.id) then
		return { error = "no_session" }
	end
	gathering[p] = nil -- the node stays claimed until the backend answers, so nobody grabs a tree about to fall
	local function release()
		if s.n then
			Nodes.release(s.n, p)
		end
	end
	if quality == nil or not Validate.quality(quality) or not inReach(p, s, 0) then
		release()
		return if quality == nil
			then { message = "It got away..." }
			elseif not Validate.quality(quality) then { error = "invalid" }
			else { message = "You walked away from the spot." }
	end
	local ok, r = Backend.post("/rbx/gather/finish", { userId = uid(p), sessionId = s.id, quality = quality })
	if not ok then
		release()
		return { message = if r.error == "too_fast" or r.error == "session_closed" then "It slipped away - try again." else "Market offline - your goods are safe" }
	end
	if s.n then
		local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		Nodes.fell(s.n, hrp and hrp.Position) -- the tree falls away from the player / the rock breaks
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

-- Forge: the backend burns the next recipe's goods and raises the tool's level; the client gets fresh balances + levels.
ForgeRF.OnServerInvoke = function(p: Player, tool: any)
	if not (tool == "axe" or tool == "pickaxe" or tool == "rod") then
		return { error = "invalid" }
	end
	if os.clock() - (lastForge[p] or 0) < 1 then
		return { error = "slow_down", message = "One moment, the forge is still hot." }
	end
	lastForge[p] = os.clock()
	local ok, r = Backend.post("/rbx/forge", { userId = uid(p), tool = tool })
	if not ok then
		return { error = r.error or "offline", message = r.message or "Market offline - try again soon." }
	end
	statsCache[p] = nil
	setForge(p, r.forge)
	StateChanged:FireClient(p, { balances = r.balances, forge = r.forge })
	return { tool = r.tool, level = r.level, name = r.name, bonus = r.bonus }
end

-- Buying a tool outside your trade: the backend pays that trade's merchant on chain; the tool appears in the Backpack.
BuyToolRF.OnServerInvoke = function(p: Player, tool: any)
	if not (tool == "axe" or tool == "pickaxe" or tool == "rod") then
		return { error = "invalid" }
	end
	if os.clock() - (lastForge[p] or 0) < 1 then
		return { error = "slow_down", message = "One moment." }
	end
	lastForge[p] = os.clock()
	local ok, r = Backend.post("/rbx/tool/buy", { userId = uid(p), tool = tool })
	if not ok then
		return { error = r.error or "offline", message = r.message or "Market offline - try again soon." }
	end
	statsCache[p] = nil
	setForge(p, r.forge)
	StateChanged:FireClient(p, { balances = r.balances, forge = r.forge })
	return { tool = r.tool, name = r.name, price = r.price }
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
					setForge(p, r.forge)
					StateChanged:FireClient(p, r)
				else
					StateChanged:FireClient(p, { offline = true })
				end
			end)
		end
		if lastState then
			Boards.renderLeaders(lobby.leaderBoard, lastState.leaderboard)
		end
	end
end)
