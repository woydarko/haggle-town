-- Run: lute run roblox/tests/NodeState.spec.luau
-- One tree / rock / fishing spot: ready -> claimed(player) -> felled -> respawning (30 s) -> ready.
local NodeState = require("../src/shared/NodeState")

local function check(cond, name)
	if not cond then
		error("FAIL " .. name)
	end
	print("ok", name)
end

-- First claim wins; a second player is refused and nothing changes for the first.
local n = NodeState.new("tree")
local ok, why = n:claim("A", 0)
check(ok and why == nil, "A claims a ready tree")
ok, why = n:claim("B", 1)
check(not ok and why == "taken", "B is refused while A chops")
check(n.owner == "A", "A still owns it")
check(n:claim("A", 2), "A may claim again (refresh)")

-- Release by someone else does nothing; release by the owner frees it.
n:release("B")
check(n.state == "claimed", "B cannot release A's claim")
n:release("A")
check(n:isReady() and n.owner == nil, "release on A leaving makes it ready")

-- Felled: refuses claims, ready again after exactly 30 s, not before.
n:claim("A", 100)
n:fell(100)
check(n.state == "felled" and n.owner == nil, "felled drops the claim")
ok, why = n:claim("B", 101)
check(not ok and why == "gone", "a felled tree refuses a claim")
check(not n:tick(129.9) and not n:isReady(), "not back before 30 s")
check(n:tick(130) and n:isReady(), "back at 30 s, tick reports the change")
check(not n:tick(131), "tick is quiet when nothing changes")

-- A claim times out after 60 s without activity (the backend session TTL).
local m = NodeState.new("rock")
m:claim("A", 0)
check(not m:tick(59) and m.state == "claimed", "still claimed at 59 s")
m:hit(50)
check(not m:tick(109) and m.state == "claimed", "a hit refreshes the idle timer")
check(m:tick(110.1) and m:isReady(), "released after 60 s idle")

-- Custom respawn time; fell is ignored unless claimed or ready (no double fell).
local r = NodeState.new("rock", 5)
r:claim("A", 0)
r:fell(0)
r:fell(3)
check(r:tick(5) and r:isReady(), "respawn uses the node's own time from the first fell")
print("NodeState.spec passed")
