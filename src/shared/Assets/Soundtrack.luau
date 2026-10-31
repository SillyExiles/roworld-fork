-- Empires Front soundtrack: free tracks from the Roblox Creator Store (APM Music and DistroKid's
-- official uploads, licensed for use in any Roblox experience). tracks: key -> {id, length (s), title,
-- pack}; moods: playlists by mood, the first title track is the opener. Played whole and crossfaded
-- by AudioDirector.
return {
	credit = "Music courtesy of APM Music and DistroKid (Roblox Creator Store)",
	license = "Roblox Creator Store",
	tracks = {
		might_of_rome = { id = "rbxassetid://1840866450", length = 104.751, title = "The Might Of Rome", pack = "Creator Store" },
		royal_supremacy = { id = "rbxassetid://1839725229", length = 121.061, title = "Royal Supremacy", pack = "Creator Store" },
		return_of_the_king = { id = "rbxassetid://1847032089", length = 111.112, title = "Return Of The King", pack = "Creator Store" },
		secrets_of_the_tomb = { id = "rbxassetid://1840866713", length = 129.489, title = "Secrets Of The Tomb", pack = "Creator Store" },
		catacombs = { id = "rbxassetid://1840867928", length = 170.109, title = "Catacombs", pack = "Creator Store" },
		temple_awakening = { id = "rbxassetid://126551633658489", length = 277.280, title = "Temple Awakening", pack = "Creator Store" },
		desert_relics = { id = "rbxassetid://121573491530187", length = 171.080, title = "Desert Relics", pack = "Creator Store" },
		eternal_monuments = { id = "rbxassetid://114221098730794", length = 311.800, title = "Eternal Monuments", pack = "Creator Store" },
		ancient_grounds = { id = "rbxassetid://9045929119", length = 128.418, title = "Ancient Grounds", pack = "Creator Store" },
		advance_of_the_legions_a = { id = "rbxassetid://1840867231", length = 106.318, title = "Advance Of The Legions", pack = "Creator Store" },
		advance_of_the_legions_b = { id = "rbxassetid://1840867266", length = 106.736, title = "Advance Of The Legions II", pack = "Creator Store" },
		battleground_a = { id = "rbxassetid://1840866101", length = 123.220, title = "Battleground", pack = "Creator Store" },
		battleground_b = { id = "rbxassetid://1840866092", length = 123.089, title = "Battleground II", pack = "Creator Store" },
		on_the_warpath = { id = "rbxassetid://1837240654", length = 114.805, title = "On The Warpath", pack = "Creator Store" },
		state_of_siege = { id = "rbxassetid://1839726082", length = 94.515, title = "State Of Siege", pack = "Creator Store" },
		epic_rider = { id = "rbxassetid://1839736658", length = 91.173, title = "Epic Rider", pack = "Creator Store" },
	},
	moods = {
		title = { "might_of_rome", "royal_supremacy", "return_of_the_king" },
		wait = { "secrets_of_the_tomb", "ancient_grounds" },
		calm = { "temple_awakening", "desert_relics", "eternal_monuments", "catacombs", "secrets_of_the_tomb", "ancient_grounds" },
		war = { "advance_of_the_legions_a", "battleground_a", "on_the_warpath", "state_of_siege", "epic_rider", "advance_of_the_legions_b", "battleground_b" },
		victory = { "return_of_the_king" },
		defeat = { "secrets_of_the_tomb" },
	},
}
