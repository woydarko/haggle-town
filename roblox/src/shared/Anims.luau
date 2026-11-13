--!strict
-- Gathering animations (R15), generated in Studio and published as private assets on the experience owner's account
-- (2026-11-12). Sources: ServerStorage.AnimationSources. The clips are long and looped, so speed/looped here set
-- how they play in game; tune after the visual pass.
local Anims = {
	ChopSwing = { id = "rbxassetid://74735327782035", speed = 4, looped = false },
	MineSwing = { id = "rbxassetid://86375683312358", speed = 2.5, looped = false },
	Cast = { id = "rbxassetid://114472562499958", speed = 3, looped = false },
	ReelLoop = { id = "rbxassetid://81642690828090", speed = 1, looped = true },
	CatchLift = { id = "rbxassetid://123334761634672", speed = 3, looped = false },
	HoldTool = { id = "rbxassetid://83778935987434", speed = 1, looped = true },
	-- NPC stance: Roblox's standard R15 idle (the default Animate script's idle clip), so mentors and merchants
	-- breathe instead of standing in a T-pose.
	Idle = { id = "rbxassetid://507766388", speed = 1, looped = true },
}

local cache: { [Humanoid]: { [string]: AnimationTrack } } = {}

-- Plays one of the clips above on a character; returns the track (nil if the character has no Animator yet).
function Anims.play(hum: Humanoid, name: string): AnimationTrack?
	local spec = (Anims :: any)[name]
	local animator = hum:FindFirstChildOfClass("Animator")
	if not (spec and animator) then
		return nil
	end
	local tracks = cache[hum]
	if not tracks then
		tracks = {}
		cache[hum] = tracks
		hum.Destroying:Once(function()
			cache[hum] = nil
		end)
	end
	local track = tracks[name]
	if not track then
		local a = Instance.new("Animation")
		a.AnimationId = spec.id
		track = animator:LoadAnimation(a)
		track.Looped = spec.looped
		track.Priority = Enum.AnimationPriority.Action
		tracks[name] = track
	end
	track:Play(0.1, 1, spec.speed)
	return track
end

function Anims.stop(hum: Humanoid, name: string)
	local t = cache[hum] and cache[hum][name]
	if t then
		t:Stop(0.2)
	end
end

return Anims
