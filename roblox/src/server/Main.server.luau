--!strict
-- Server entry: builds the town, validates every client intent, forwards it to the backend, pushes state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Backend = require(script.Parent.Backend)
local World = require(script.Parent.World)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Validate = require(Shared:WaitForChild("Validate"))

local world = World.build()

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
local Haggle, Accept = rf("Haggle"), rf("Accept")
local StateChanged, OpenHaggle, Toast = re("StateChanged"), re("OpenHaggle"), re("Toast")
remotes.Parent = ReplicatedStorage

local issued: { [Player]: { [string]: boolean } } = {}
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
end)

for good, nodePart in world.nodes do
	local pp = nodePart:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
	pp.Triggered:Connect(function(p)
		if not (Validate.good(good) and Validate.near(distance(p, nodePart))) then
			return
		end
		local ok, r = Backend.post("/rbx/gather", { userId = uid(p), good = good })
		if ok then
			StateChanged:FireClient(p, { balances = r.balances })
			Toast:FireClient(p, "+1 " .. good)
		elseif r.error == "cooldown" then
			Toast:FireClient(p, "Resting... " .. math.ceil((r.cooldownMs or 0) / 1000) .. "s")
		else
			Toast:FireClient(p, "Market offline - your goods are safe")
		end
	end)
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
	end
end)
