--!strict
-- Pure minigame scoring math (no Roblox globals) so roblox/tests/Minigame.spec.luau runs under Lute.
-- The score only nudges luck; the server rolls the item (docs/superpowers/specs/2026-11-11-haggle-town-v2-design.md s5-6).

local Minigame = {
	CAST_PERIOD = 1.4, -- seconds for the cast bar to rise and fall once
	TOP_BAND = 0.85, -- releasing at or above this is a long cast
	BITE_WINDOW = 0.8, -- seconds to react to the "!"
	REEL_START = 0.25, -- reel progress at the start
	ZONE = 0.28, -- catch zone height as a share of the reel bar (x params.zoneScale)
	FILL = 0.22, -- progress per second while the fish is in the zone
	DRAIN = 0.15, -- progress lost per second outside, x fish speed
}

local function clamp01(x: number): number
	if x ~= x then
		return 0 -- NaN
	end
	return math.clamp(x, 0, 1)
end

-- Cast bar position while charging: ping-pongs 0 -> 1 -> 0 over CAST_PERIOD.
function Minigame.castPower(t: number): number
	local phase = (t % Minigame.CAST_PERIOD) / Minigame.CAST_PERIOD
	return 1 - math.abs(1 - 2 * phase)
end

-- 0..1: share of reel time the fish spent in the zone, scaled by the cast (long cast = full credit).
function Minigame.fishingQuality(timeInZoneRatio: number, castPower: number): number
	local cast = clamp01(castPower)
	local castScore = if cast >= Minigame.TOP_BAND then 1 else cast * 0.8
	return clamp01(clamp01(timeInZoneRatio) * (0.7 + 0.3 * castScore))
end

-- Reel progress change for one frame.
function Minigame.catchProgress(inZone: boolean, dt: number, speed: number): number
	return if inZone then Minigame.FILL * dt else -Minigame.DRAIN * speed * dt
end

return Minigame
