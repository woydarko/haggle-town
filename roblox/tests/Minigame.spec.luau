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
-- chopping
check(Minigame.chopQuality(4, 4) == 1, "4 swings, all perfect -> 1")
check(near(Minigame.chopQuality(4, 0), 0.5), "4 swings, no perfects -> 0.5")
check(Minigame.chopQuality(8, 0) < Minigame.chopQuality(4, 0), "misses lower the score")
check(Minigame.chopQuality(0, 0) == 0 and Minigame.chopQuality(4, 9) <= 1, "no swings -> 0, perfects capped")
check(Minigame.chopHit(0.5, 0.5, 0.2) == "perfect", "center of the spot is perfect")
check(Minigame.chopHit(0.58, 0.5, 0.2) == "good", "inside the spot is good")
check(Minigame.chopHit(0.62, 0.5, 0.2) == "miss", "outside the spot misses")
check(Minigame.chopHit(0.525, 0.5, 0.2) == "perfect" and Minigame.chopHit(0.535, 0.5, 0.2) == "good", "perfect band is the center 30% of the spot")

-- mining
check(Minigame.mineQuality(5, 5) == 1 and Minigame.mineQuality(0, 5) == 0, "accuracy")
check(near(Minigame.mineQuality(3, 5), 0.6), "3 of 5 -> 0.6")
check(Minigame.mineQuality(1, 0) == 0 and Minigame.mineQuality(9, 5) == 1, "zero total and overflow safe")
check(Minigame.mineFade("ore_deep") < Minigame.mineFade("ore_mouth"), "deep cave fades faster")
print("Minigame.spec passed")
