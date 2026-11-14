--!strict
-- Image icons: ForgeGUI-generated, published as a private Image on the owner's Roblox account (credits in
-- roblox/ASSETS.md). Items use code-drawn pixel sprites (shared/Sprites.luau) instead.
local Icons = {
	coin = "rbxassetid://114408141984568",
}

-- A Roblox player's headshot (head and shoulders), served by Roblox for any UserId: no upload, no API call.
function Icons.headshot(userId: string | number): string
	return `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
end

return Icons
