-- Run: lute run roblox/tests/Validate.spec.luau
local Validate = require("../src/shared/Validate")

local function check(cond, name)
	if not cond then
		error("FAIL " .. name)
	end
	print("ok", name)
end

check(Validate.node("wood") and Validate.node("fish") and Validate.node("ore_mouth") and Validate.node("ore_deep"), "known gather nodes")
check(not Validate.node("iron") and not Validate.node(nil) and not Validate.node(5), "unknown node rejected")
check(Validate.quality(0) and Validate.quality(1) and Validate.quality(0.42), "quality 0..1")
check(not Validate.quality(1.1) and not Validate.quality(-0.1) and not Validate.quality(0 / 0) and not Validate.quality("1"), "bad quality rejected")
check(Validate.merchant("smith") and not Validate.merchant("king"), "merchant names")
check(Validate.class("fisher") and Validate.class("logger") and Validate.class("miner"), "class names")
check(not Validate.class("wizard") and not Validate.class(nil) and not Validate.class(1), "unknown class rejected")
check(Validate.near(11.9) and not Validate.near(12.1) and not Validate.near(nil), "distance limit 12 studs")
check(Validate.text("hi") and not Validate.text("") and not Validate.text("   "), "empty text rejected")
check(Validate.text(string.rep("x", 200)) and not Validate.text(string.rep("x", 201)), "201-char text rejected")
check(not Validate.text(42), "non-string text rejected")
local issued = { ["deal-1"] = true }
check(Validate.deal(issued, "deal-1"), "own deal accepted")
check(not Validate.deal(issued, "deal-2"), "foreign dealId rejected")
check(not Validate.deal(issued, nil), "nil dealId rejected")
print("Validate.spec passed")
