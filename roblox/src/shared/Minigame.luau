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
	CHOP_HITS = 4, -- good hits to fell a tree
	CHOP_MAX_SWINGS = 10, -- more swings than this and the tree is not cut
	CHOP_SPOT = 0.16, -- sweet spot width as a share of the bar (x params.zoneScale)
	CHOP_PERIOD = 1.1, -- needle sweep, seconds there and back
	MINE_POINTS = 5,
}

local function clamp01(x: number): number
	if x ~= x then
		return 0 -- NaN
	end
	return math.clamp(x, 0, 1)
end

-- 0 -> 1 -> 0 over `period` seconds; drives the cast bar and the chopping needle.
function Minigame.pingPong(t: number, period: number): number
	local phase = (t % period) / period
	return 1 - math.abs(1 - 2 * phase)
end

function Minigame.castPower(t: number): number
	return Minigame.pingPong(t, Minigame.CAST_PERIOD)
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

-- One swing: inside the center 30% of the spot is perfect, inside the spot is good.
function Minigame.chopHit(needle: number, center: number, width: number): "perfect" | "good" | "miss"
	local d = math.abs(needle - center)
	return if d <= width * 0.15 then "perfect" elseif d <= width / 2 then "good" else "miss"
end

-- Half for few wasted swings, half for perfect hits.
function Minigame.chopQuality(swings: number, perfects: number): number
	if swings <= 0 then
		return 0
	end
	local n = Minigame.CHOP_HITS
	return clamp01(0.5 * math.min(n / swings, 1) + 0.5 * math.min(perfects / n, 1))
end

function Minigame.mineQuality(hitPoints: number, totalPoints: number): number
	return if totalPoints > 0 then clamp01(hitPoints / totalPoints) else 0
end

-- Seconds a weak point glows before it fades; the deep cave is faster.
function Minigame.mineFade(node: string): number
	return if node == "ore_deep" then 0.7 else 0.9
end

return Minigame
