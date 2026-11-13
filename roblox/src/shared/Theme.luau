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
	-- Fondamento: hand-lettered market-sign voice for titles and names (readable from 20 px).
	-- Merriweather: screen-reading serif for body and chat, matches the parchment look; bold for prices.
	display = Font.fromName("Fondamento"),
	body = Font.fromName("Merriweather"),
	numeric = Font.fromName("Merriweather", Enum.FontWeight.Bold),
	radius = UDim.new(0, 8),
	space = 8,
}

Theme.merchantNames = { woodcutter = "Woodcutter", fishmonger = "Fishmonger", smith = "Smith" }
Theme.ore = Theme.iron -- item category name
-- Rarity colors (spec: common grey, rare blue, epic purple, legendary gold), >= 4.5:1 on background and surface.
Theme.tiers = {
	common = Color3.fromHex("5B626C"),
	rare = Color3.fromHex("2A5FB4"),
	epic = Color3.fromHex("8A3FC2"),
	legendary = Color3.fromHex("8A5E00"),
}
Theme.classNames = { fisher = "Fisher", logger = "Logger", miner = "Miner" }
Theme.categoryNames = { fish = "Fish", wood = "Wood", ore = "Ore" }

return Theme
