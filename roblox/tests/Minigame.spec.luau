-- Run: lute run roblox/tests/Minigame.spec.luau
local Minigame = require("../src/shared/Minigame")

local function check(cond, name)
	if not cond then
		error("FAIL " .. name)
	end
	print("ok", name)
end
local function near(a, b)
	return math.abs(a - b) < 1e-9
end

-- fishing quality
check(Minigame.fishingQuality(1, 1) == 1, "full zone + perfect cast -> 1")
check(Minigame.fishingQuality(0, 1) == 0 and Minigame.fishingQuality(0, 0) == 0, "never in zone -> 0")
check(Minigame.fishingQuality(1, 0.85) == 1, "top band counts as a perfect cast")
check(Minigame.fishingQuality(1, 0.5) < Minigame.fishingQuality(1, 0.85), "short cast scores lower")
check(near(Minigame.fishingQuality(0.5, 1), 0.5), "half time in zone, perfect cast -> 0.5")
check(Minigame.fishingQuality(2, 3) == 1 and Minigame.fishingQuality(-1, -1) == 0, "inputs clamped")
check(Minigame.fishingQuality(0 / 0, 1) == 0, "NaN ratio -> 0")

-- reel progress
check(Minigame.catchProgress(true, 1, 1) > 0, "in zone fills")
check(Minigame.catchProgress(false, 1, 1) < 0, "out of zone drains")
check(Minigame.catchProgress(false, 1, 2) < Minigame.catchProgress(false, 1, 1), "faster fish drains faster")
check(Minigame.catchProgress(true, 0, 1) == 0, "no time, no change")

-- cast power ping-pong
check(Minigame.castPower(0) == 0 and near(Minigame.castPower(Minigame.CAST_PERIOD / 2), 1), "cast bar rises to full")
check(near(Minigame.castPower(Minigame.CAST_PERIOD), 0), "cast bar falls back")
print("Minigame.spec passed")
