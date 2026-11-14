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
	wood = Color3.fromHex("965A16"), -- wood, fish, warning darkened in v4 to pass 4.5:1 as text on background
	fish = Color3.fromHex("1B7270"),
	iron = Color3.fromHex("4F5D6B"),
	success = Color3.fromHex("2F7A3B"),
	warning = Color3.fromHex("8C5F07"),
	error = Color3.fromHex("A12C2C"),
	-- Fondamento: hand-lettered market-sign voice for titles and names (readable from 20 px).
	-- Merriweather: screen-reading serif for body and chat, matches the parchment look; bold for prices.
	display = Font.fromName("Fondamento"),
	body = Font.fromName("Merriweather"),
	numeric = Font.fromName("Merriweather", Enum.FontWeight.Bold),
	radius = UDim.new(0, 8),
	space = 8,
}

-- Type scale (DESIGN_SYSTEM s4): every text picks one style, never a raw size.
--   display (Fondamento): title 30 panel titles, heading 24 names, label 20 buttons/tabs/section labels
--   body (Merriweather): body 18 sentences, small 16 secondary lines, caption 14 badges/stamps/dense meta only
--   numeric (Merriweather Bold): price 24 the live offer, number 20 balances/values, numberSmall 16 counts in rows
Theme.type = {
	hero = { font = Theme.display, size = 72 },
	title = { font = Theme.display, size = 30 },
	heading = { font = Theme.display, size = 24 },
	label = { font = Theme.display, size = 20 },
	body = { font = Theme.body, size = 18 },
	small = { font = Theme.body, size = 16 },
	caption = { font = Theme.body, size = 14 },
	price = { font = Theme.numeric, size = 24 },
	number = { font = Theme.numeric, size = 20 },
	numberSmall = { font = Theme.numeric, size = 16 },
} :: { [string]: { font: Font, size: number } }

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
