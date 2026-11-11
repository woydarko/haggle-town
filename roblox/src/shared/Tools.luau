--!strict
-- The three gathering tools every player carries. tag = CollectionService tag of the nodes the tool works on.
-- Text here is player-facing (toasts), so it follows the copy rules in AGENTS.md.
local Tools = {
	Axe = { tag = "GatherTree", tip = "Chop trees", noTarget = "Walk up to a tree and swing your axe", taken = "Someone is chopping this tree", gone = "This tree grows back soon" },
	Pickaxe = { tag = "GatherRock", tip = "Mine rocks", noTarget = "Walk up to a rock and swing your pickaxe", taken = "Someone is mining this rock", gone = "This rock is still regrowing" },
	Rod = { tag = "GatherWater", tip = "Fish in the lake or the sea", noTarget = "Stand by the water at a fishing spot", taken = "Someone is fishing here", gone = "No fish here right now" },
}

return Tools
