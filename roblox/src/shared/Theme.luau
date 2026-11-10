--!strict
-- Design tokens from docs/DESIGN_SYSTEM.md. UI code reads colors and fonts only from here.
local Theme = {
	background = Color3.fromHex("F4ECDD"),
	surface = Color3.fromHex("FFF9EE"),
	border = Color3.fromHex("D9C7A6"),
	text = Color3.fromHex("2B2118"),
	muted = Color3.fromHex("6E5D4A"),
	primary = Color3.fromHex("B4471F"),
	onPrimary = Color3.fromHex("FFF9EE"),
	wood = Color3.fromHex("A8661C"),
	fish = Color3.fromHex("1E7A78"),
	iron = Color3.fromHex("4F5D6B"),
	success = Color3.fromHex("2F7A3B"),
	warning = Color3.fromHex("B07A12"),
	error = Color3.fromHex("A12C2C"),
	display = Enum.Font.FredokaOne,
	body = Enum.Font.BuilderSans,
	numeric = Enum.Font.RobotoMono,
	radius = UDim.new(0, 8),
	space = 8,
}

Theme.merchantNames = { woodcutter = "Woodcutter", fishmonger = "Fishmonger", smith = "Smith" }
Theme.goodOf = { woodcutter = "wood", fishmonger = "fish", smith = "iron" }

return Theme
