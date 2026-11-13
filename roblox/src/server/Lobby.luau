--!strict
-- Lobby at the village edge: spawn, three class mentors, How to play + rarity boards, leaderboard, gate to town.
-- Built after World.build (uses World.kit). Main.server wires the mentor prompts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local World = require(script.Parent.World)
local Boards = require(script.Parent.Boards)
local Terrain = require(script.Parent.Terrain)

local Lobby = {}

local SPOT = Terrain.SPOTS.lobby
local C = Vector3.new(SPOT.x, SPOT.y, SPOT.z) -- lobby center; the town square is north (+Z)
local MENTORS = { { "fisher", -14, Theme.fish }, { "logger", 0, Theme.wood }, { "miner", 14, Theme.iron } }

export type Built = { mentors: { [string]: BasePart }, leaderBoard: Part }

local function facingCenter(at: Vector3): CFrame
	return CFrame.lookAt(C + at, C + Vector3.new(0, at.Y, at.Z))
end

function Lobby.build(): Built
	local k = World.kit
	k.part({ Name = "LobbyFloor", Size = Vector3.new(60, 0.4, 48), Position = C + Vector3.new(0, 0.2, 0), Color = Color3.fromHex("CDBB9A"), Material = Enum.Material.Cobblestone })

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.Position = C + Vector3.new(0, 0.6, 8)
	spawn.Neutral = true
	spawn.Color = Theme.border
	spawn.Material = Enum.Material.Cobblestone
	spawn.Parent = workspace

	local mentors: { [string]: BasePart } = {}
	for _, m in MENTORS do
		local cls, x, color = m[1] :: string, m[2] :: number, m[3] :: Color3
		local name = Theme.classNames[cls]
		mentors[cls] = k.npc(cls .. "Mentor", C + Vector3.new(x, 0.4, -12), color, `{name} mentor`, `Become a {name}`, Vector3.new(0, 0, 1))
	end

	local how = k.board("HowToPlay", facingCenter(Vector3.new(-24, 8.4, -6)))
	Boards.renderSteps(how, "How trading works", {
		{ pictures = { "fish_sardine", "wood_pine", "ore_copper" }, text = "1. Pick a trade from a mentor" },
		{ pictures = { "rod", "axe", "pickaxe" }, text = "2. Click water, a tree or a rock" },
		{ pictures = { "fish_sardine", "fish_koi" }, text = "3. Play well for rarer finds" },
		{ pictures = { "coin" }, text = "4. Haggle at the stalls" },
	}, "Keys 1, 2, 3 pick your tool. Tab opens your bag. The big board in the square shows prices.")
	local rarity = k.board("Rarity", facingCenter(Vector3.new(24, 8.4, -6)))
	Boards.renderRarity(rarity)
	local leaders = k.board("LobbyLeaders", facingCenter(Vector3.new(-24, 8.4, 12)))

	-- Gate to the town square.
	for _, x in { -6, 6 } do
		k.part({ Name = "GatePillar", Size = Vector3.new(2, 10, 2), Position = C + Vector3.new(x, 5.4, 24), Color = Color3.fromHex("6B4A2B"), Material = Enum.Material.Wood })
		k.lamp(C + Vector3.new(x * 1.6, 0.4, 24))
	end
	local beam = k.part({ Name = "GateBeam", Size = Vector3.new(14, 1.6, 2), Position = C + Vector3.new(0, 11.2, 24), Color = Color3.fromHex("6B4A2B"), Material = Enum.Material.Wood })
	k.label(beam, "To the market", Theme.primary, 2.5)

	return { mentors = mentors, leaderBoard = leaders }
end

return Lobby
