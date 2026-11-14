--!strict
-- 12x12 pixel-art item icons drawn in code (block-game inventory look, no uploaded images).
-- One silhouette per category; tiers change the palette. '.' is transparent, 's' marks extra spots.
-- No Roblox globals so roblox/tests/Sprites.spec.luau runs under Lute; client/ui/Ui.luau turns runs into Frames.

export type Sprite = { rows: { string }, palette: { [string]: string } }
export type Run = { row: number, col: number, len: number, hex: string }

local E = "............"
local SHAPES = {
	-- o outline, a body, b belly, e eye, t tail
	fish = { E, E, "....oooo....", "..ooaaaao..t", ".oaaaaaaaoot", "oaeaaaaaaatt", "oaaaaaaaaatt", ".obbbbbbboot", "..oobbbbo..t", "....oooo....", E, E },
	-- o bark outline, c cut face, r growth ring, k bark, h bark highlight
	wood = { E, E, ".oooooooooo.", "occcokhkhkko", "ocrrckkkkhko", "ocrcrkhkkkko", "ocrcrkkkhkko", "ocrrckhkkkko", "occcokkkkhko", ".oooooooooo.", E, E },
	-- o outline, h highlight, a face, d shade
	ore = { E, E, ".....ooo....", "...oohhao...", "..ohhaaaaoo.", ".ohaaaaaadao", ".oaaaaaaddao", "oaaaaadddddo", "oaaadddddddo", ".ooooooooooo", E, E },
}

local DEFS: { [string]: { shape: string, palette: { [string]: string }, spots: { { number } }? } } = {
	fish_sardine = { shape = "fish", palette = { o = "2C3640", a = "9DB2C0", b = "E4ECF1", e = "111418", t = "70879A" } },
	fish_trout = {
		shape = "fish",
		palette = { o = "35311C", a = "7D8A4C", b = "E8C3AE", e = "111418", t = "5F6B38", s = "3A4220" },
		spots = { { 5, 5 }, { 5, 8 }, { 6, 6 }, { 6, 9 }, { 7, 4 }, { 7, 7 } },
	},
	fish_salmon = { shape = "fish", palette = { o = "5A2618", a = "E27458", b = "F7C6AA", e = "111418", t = "BC5640" } },
	fish_koi = {
		shape = "fish",
		palette = { o = "6A3A00", a = "F4B630", b = "FFF3D1", e = "111418", t = "E5862A", s = "E2451F" },
		spots = { { 5, 6 }, { 5, 7 }, { 6, 7 }, { 6, 8 }, { 7, 5 }, { 7, 9 } },
	},
	wood_pine = { shape = "wood", palette = { o = "4B3420", c = "EBD29E", r = "C7A262", k = "7C5532", h = "A0703F" } },
	wood_oak = { shape = "wood", palette = { o = "38240F", c = "D6AF70", r = "9E733C", k = "5C3B1C", h = "7F5630" } },
	wood_maple = { shape = "wood", palette = { o = "4A2016", c = "F1C7A0", r = "C9785A", k = "8E3A24", h = "B5502F" } },
	wood_redwood = { shape = "wood", palette = { o = "33100A", c = "E59468", r = "A43F27", k = "74190F", h = "A3301C" } },
	ore_copper = { shape = "ore", palette = { o = "4A2814", h = "F6AE78", a = "C86A34", d = "8A431E" } },
	ore_iron = { shape = "ore", palette = { o = "2C3036", h = "EEF1F4", a = "A8B0B8", d = "6A737C" } },
	ore_gold = { shape = "ore", palette = { o = "5A3B00", h = "FFF2A6", a = "F3C232", d = "BC860F" } },
	ore_crystal = {
		shape = "ore",
		palette = { o = "2A1450", h = "EFFBFF", a = "7BD6F0", d = "8C5BD9", s = "FFFFFF" },
		spots = { { 7, 4 }, { 9, 6 }, { 8, 9 } },
	},
}

local SPRITES: { [string]: Sprite } = {}
for id, def in DEFS do
	local rows = table.clone(SHAPES[def.shape])
	for _, p in def.spots or {} do
		local r, c = p[1], p[2]
		rows[r] = string.sub(rows[r], 1, c - 1) .. "s" .. string.sub(rows[r], c + 1)
	end
	SPRITES[id] = { rows = rows, palette = def.palette }
end

-- The fish on the reel bar: an all-black silhouette, since nobody knows what bit until it is landed.
SPRITES.fish_mystery = { rows = SHAPES.fish, palette = { o = "050506", a = "17171C", b = "24242B", e = "D8D8DE", t = "0E0E12" } }

-- Tools for the lobby how-to board (one-offs, so full rows): w handle, m metal, h edge, l line, k hook, r grip.
SPRITES.axe = {
	rows = { E, "......mm..w.", ".....mmmmw..", "....hmmmw...", "....hmmw....", ".....hw.....", ".....w......", "....w.......", "...w........", "..w.........", ".w..........", E },
	palette = { w = "7A4E24", m = "6F7880", h = "C9D0D6" },
}
SPRITES.pickaxe = {
	rows = { E, "....mmmmmmm.", "...mmmmmmwmm", "........w.mm", ".......w..mm", "......w...mm", ".....w....m.", "....w....m..", "...w........", "..w.........", ".w..........", E },
	palette = { w = "7A4E24", m = "6F7880" },
}
SPRITES.rod = {
	rows = { E, "..........wl", ".........w.l", "........w..l", ".......w...l", "......w....l", ".....w.....l", "....w......l", "...w......kk", "..w.........", ".r..........", E },
	palette = { w = "7A4E24", l = "5B626C", k = "5B626C", r = "B4471F" },
}

-- Forge levels recolour the tools: 1 Worn (grey iron), 2 Sturdy (copper), 3 Master (bright steel, gold trim).
local LEVEL_PALETTE = {
	{ m = "6F7880", h = "C9D0D6", w = "7A4E24", l = "5B626C", k = "5B626C", r = "B4471F" },
	{ m = "C86A34", h = "F6AE78", w = "6B3F1C", l = "5B626C", k = "C86A34", r = "2A5FB4" },
	{ m = "B9C3CC", h = "FFFFFF", w = "4A2C14", l = "8A5E00", k = "F3C232", r = "8A3FC2" },
}
for _, tool in { "axe", "pickaxe", "rod" } do
	local base = SPRITES[tool]
	for level, pal in LEVEL_PALETTE do
		local p = {}
		for ch, hex in base.palette do
			p[ch] = pal[ch] or hex
		end
		SPRITES[`{tool}_{level}`] = { rows = base.rows, palette = p }
	end
end

-- Anvil for the Forge button and panel: o outline, h face highlight, a body.
SPRITES.anvil = {
	rows = { E, E, "oooooooooooo", "ohhhhhhhhhho", ".oaaaaaaaao.", "..ooaaaaoo..", "...oaaaao...", "...oaaaao...", "..oaaaaaao..", ".oaaaaaaaao.", ".oooooooooo.", E },
	palette = { o = "2C3036", h = "C9D0D6", a = "6F7880" },
}

local Sprites = { SIZE = 12 }

function Sprites.get(id: string): Sprite?
	return SPRITES[id]
end

-- Horizontal runs of one colour, so an icon is ~40 Frames instead of ~80 single pixels.
function Sprites.runs(id: string): { Run }
	local s = SPRITES[id]
	local out: { Run } = {}
	if not s then
		return out
	end
	for r, row in s.rows do
		local c = 1
		while c <= #row do
			local ch = string.sub(row, c, c)
			local len = 1
			while string.sub(row, c + len, c + len) == ch do
				len += 1
			end
			if ch ~= "." then
				table.insert(out, { row = r, col = c, len = len, hex = s.palette[ch] })
			end
			c += len
		end
	end
	return out
end

return Sprites
