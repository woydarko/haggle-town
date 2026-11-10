-- Run: lute run roblox/tests/Validate.spec.luau
local Validate = require("../src/shared/Validate")

local function check(cond, name)
	if not cond then
		error("FAIL " .. name)
	end
	print("ok", name)
end

check(Validate.good("wood") and Validate.good("fish") and Validate.good("iron"), "known goods")
check(not Validate.good("gold") and not Validate.good(nil) and not Validate.good(5), "unknown good rejected")
check(Validate.merchant("smith") and not Validate.merchant("king"), "merchant names")
check(Validate.near(11.9) and not Validate.near(12.1) and not Validate.near(nil), "distance limit 12 studs")
check(Validate.text("hi") and not Validate.text("") and not Validate.text("   "), "empty text rejected")
check(Validate.text(string.rep("x", 200)) and not Validate.text(string.rep("x", 201)), "201-char text rejected")
check(not Validate.text(42), "non-string text rejected")
local issued = { ["deal-1"] = true }
check(Validate.deal(issued, "deal-1"), "own deal accepted")
check(not Validate.deal(issued, "deal-2"), "foreign dealId rejected")
check(not Validate.deal(issued, nil), "nil dealId rejected")
print("Validate.spec passed")
