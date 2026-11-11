--!strict
-- Sound effects from the Roblox audio library (free Creator Store sounds; most "Courtesy of Pro Sound Effects").
-- Client-side helpers: at() plays a 3D sound at a world point, ui() a 2D sound for this player only.
local SoundService = game:GetService("SoundService")

local Sfx = {
	ids = {
		chop = "rbxassetid://9120950231", -- Wood Pound Dirt Two Wood Poles 1
		chopPerfect = "rbxassetid://9120946512", -- Wood Pound Dirt Banging Two Poles 5
		timber = "rbxassetid://9120957463", -- Wood Roof Crash 1
		leaves = "rbxassetid://9114518245", -- Foliage Movement 3
		respawn = "rbxassetid://132948338000932", -- bubble pop sound effect
	} :: { [string]: string },
}

function Sfx.at(name: string, pos: Vector3, volume: number?, speed: number?)
	local id = Sfx.ids[name]
	if not id then
		return
	end
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.7
	s.PlaybackSpeed = speed or (0.92 + math.random() * 0.16) -- small pitch spread so repeats do not sound robotic
	s.RollOffMaxDistance = 120
	s.Parent = a
	s.Ended:Once(function()
		a:Destroy()
	end)
	s:Play()
	task.delay(8, function()
		if a.Parent then
			a:Destroy()
		end
	end)
end

function Sfx.ui(name: string)
	local id = Sfx.ids[name]
	if id then
		local s = Instance.new("Sound")
		s.SoundId = id
		SoundService:PlayLocalSound(s)
	end
end

return Sfx
