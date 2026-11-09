class_name ZoneData
## Zones of Eorzea and how they connect (matching FFXIV's map).
## exits: dir is the map edge the zone line sits on. Fields are 260 m squares; cities are hand-laid kits.
## mobs: [species, count]; hunts: large monsters that live here; water: "sea" edge, "lake" pools, or "river".

const SIZE := 260.0

static func all() -> Dictionary:
	return {
		# ======================= CITIES
		"gridania": {"name": "Gridania", "region": "The Black Shroud", "type": "city", "style": "gridania", "aetheryte": "New Gridania",
			"guild": "The Carline Canopy", "guildmaster": "miounne", "exits": [{"to": "central_shroud", "dir": "S"}, {"to": "north_shroud", "dir": "W"}],
			"water": "river", "music": "forest"},
		"limsa": {"name": "Limsa Lominsa", "region": "La Noscea", "type": "city", "style": "limsa", "aetheryte": "Limsa Lominsa",
			"guild": "The Drowning Wench", "guildmaster": "baderon", "exits": [{"to": "middle_la_noscea", "dir": "N"}, {"to": "lower_la_noscea", "dir": "E"}],
			"ferry": {"to": "western_thanalan", "name": "Ferry to Vesper Bay"}, "water": "sea", "music": "sea"},
		"uldah": {"name": "Ul'dah", "region": "Thanalan", "type": "city", "style": "uldah", "aetheryte": "Ul'dah",
			"guild": "The Quicksand", "guildmaster": "momodi", "exits": [{"to": "central_thanalan", "dir": "N"}, {"to": "western_thanalan", "dir": "W"}],
			"water": "", "music": "desert"},
		"ishgard": {"name": "Foundation", "region": "Coerthas", "type": "city", "style": "ishgard", "aetheryte": "Foundation",
			"guild": "The Forgotten Knight", "guildmaster": "gibrillont", "exits": [{"to": "coerthas_central", "dir": "S"}],
			"water": "", "music": "snow", "snow": true},
		# ======================= THE BLACK SHROUD
		"central_shroud": {"name": "Central Shroud", "region": "The Black Shroud", "type": "field", "biome": "forest", "lvl": [1, 6], "aetheryte": "Bentbranch Meadows",
			"exits": [{"to": "gridania", "dir": "N"}, {"to": "east_shroud", "dir": "E"}, {"to": "south_shroud", "dir": "S"}],
			"mobs": [["squirrel", 6], ["funguar", 5], ["ladybug", 4], ["boar", 3]], "hunts": ["morbol"], "water": "lake",
			"landmarks": [["Bentbranch Meadows", -30, 30], ["Jadeite Flood", 40, -10], ["Galvanth's Spire", -60, -50], ["Sanctum of the Twelve", 70, 70]]},
		"east_shroud": {"name": "East Shroud", "region": "The Black Shroud", "type": "field", "biome": "forest", "lvl": [5, 12], "aetheryte": "The Hawthorne Hut",
			"exits": [{"to": "central_shroud", "dir": "W"}, {"to": "south_shroud", "dir": "S"}],
			"mobs": [["boar", 5], ["treant", 4], ["funguar", 4], ["ladybug", 4]], "hunts": ["morbol", "coeurl"], "water": "river",
			"landmarks": [["The Hawthorne Hut", 10, 20], ["Sylphlands", 70, -60], ["Larkscall", -50, -40]]},
		"south_shroud": {"name": "South Shroud", "region": "The Black Shroud", "type": "field", "biome": "forest", "lvl": [8, 15], "aetheryte": "Quarrymill",
			"exits": [{"to": "central_shroud", "dir": "N"}, {"to": "east_shroud", "dir": "E"}, {"to": "eastern_thanalan", "dir": "S"}],
			"mobs": [["treant", 5], ["boar", 5], ["squirrel", 4]], "hunts": ["coeurl"], "water": "lake",
			"landmarks": [["Quarrymill", -20, -20], ["Camp Tranquil", 40, 50], ["Urth's Gift", 70, -50]]},
		"north_shroud": {"name": "North Shroud", "region": "The Black Shroud", "type": "field", "biome": "forest", "lvl": [3, 10], "aetheryte": "Fallgourd Float",
			"exits": [{"to": "gridania", "dir": "E"}, {"to": "coerthas_central", "dir": "N"}],
			"mobs": [["funguar", 5], ["treant", 3], ["ladybug", 5], ["boar", 3]], "hunts": ["morbol"], "water": "lake",
			"landmarks": [["Fallgourd Float", 0, -30], ["Peacegarden", -60, 30], ["Proud Creek", 50, 40]]},
		# ======================= LA NOSCEA
		"middle_la_noscea": {"name": "Middle La Noscea", "region": "La Noscea", "type": "field", "biome": "coast", "lvl": [1, 6], "aetheryte": "Summerford Farms",
			"exits": [{"to": "limsa", "dir": "SW"}, {"to": "lower_la_noscea", "dir": "SE"}, {"to": "western_la_noscea", "dir": "NW"}, {"to": "eastern_la_noscea", "dir": "E"}],
			"mobs": [["pugil", 5], ["dodo", 5], ["ladybug", 4], ["marmot", 3]], "hunts": ["pugil_great"], "water": "sea",
			"landmarks": [["Summerford Farms", 10, 10], ["Seasong Grotto", -60, 60], ["Three-malm Bend", 50, -40]]},
		"lower_la_noscea": {"name": "Lower La Noscea", "region": "La Noscea", "type": "field", "biome": "coast", "lvl": [2, 8], "aetheryte": "Moraby Drydocks",
			"exits": [{"to": "limsa", "dir": "W"}, {"to": "middle_la_noscea", "dir": "NW"}, {"to": "eastern_la_noscea", "dir": "N"}],
			"mobs": [["pugil", 6], ["dodo", 4], ["bomb", 3]], "hunts": ["pugil_great"], "water": "sea",
			"landmarks": [["Moraby Drydocks", 20, 40], ["Candlekeep Quay", 60, -20], ["Red Rooster Stead", -40, -30]]},
		"eastern_la_noscea": {"name": "Eastern La Noscea", "region": "La Noscea", "type": "field", "biome": "coast", "lvl": [10, 18], "aetheryte": "Costa del Sol",
			"exits": [{"to": "lower_la_noscea", "dir": "S"}, {"to": "middle_la_noscea", "dir": "W"}, {"to": "upper_la_noscea", "dir": "N"}],
			"mobs": [["bomb", 4], ["coblyn", 4], ["dodo", 4], ["pugil", 4]], "hunts": ["pugil_great", "coeurl"], "water": "sea",
			"landmarks": [["Costa del Sol", 60, 60], ["Wineport", -30, -20], ["Bloodshore", 70, -40]]},
		"western_la_noscea": {"name": "Western La Noscea", "region": "La Noscea", "type": "field", "biome": "coast", "lvl": [8, 14], "aetheryte": "Swiftperch",
			"exits": [{"to": "middle_la_noscea", "dir": "E"}, {"to": "upper_la_noscea", "dir": "N"}],
			"mobs": [["pugil", 5], ["coblyn", 3], ["bomb", 3]], "hunts": ["pugil_great"], "water": "sea",
			"landmarks": [["Swiftperch", -20, 40], ["Aleport", 0, -10], ["Isles of Umbra", -80, -70]]},
		"upper_la_noscea": {"name": "Upper La Noscea", "region": "La Noscea", "type": "field", "biome": "highland", "lvl": [12, 18], "aetheryte": "Camp Bronze Lake",
			"exits": [{"to": "western_la_noscea", "dir": "SW"}, {"to": "eastern_la_noscea", "dir": "SE"}, {"to": "outer_la_noscea", "dir": "N"}],
			"mobs": [["coblyn", 5], ["bomb", 4], ["dodo", 3]], "hunts": ["coeurl"], "water": "lake",
			"landmarks": [["Camp Bronze Lake", 30, 20], ["Oakwood", -50, 30], ["Zelma's Run", 0, -60]]},
		"outer_la_noscea": {"name": "Outer La Noscea", "region": "La Noscea", "type": "field", "biome": "highland", "lvl": [16, 22], "aetheryte": "Camp Overlook",
			"exits": [{"to": "upper_la_noscea", "dir": "S"}],
			"mobs": [["coblyn", 6], ["bomb", 4]], "hunts": ["adamantoise"], "water": "lake",
			"landmarks": [["Camp Overlook", 0, 40], ["U'Ghamaro Mines", -40, -40], ["Iron Lake", 50, -20]]},
		# ======================= THANALAN
		"western_thanalan": {"name": "Western Thanalan", "region": "Thanalan", "type": "field", "biome": "desert", "lvl": [1, 6], "aetheryte": "Horizon",
			"exits": [{"to": "uldah", "dir": "E"}, {"to": "central_thanalan", "dir": "NE"}],
			"ferry": {"to": "limsa", "name": "Ferry to Limsa Lominsa (Vesper Bay)"},
			"mobs": [["marmot", 6], ["cactuar", 4], ["antling", 4], ["bandit", 3]], "hunts": ["coeurl"], "water": "sea",
			"landmarks": [["Horizon", 20, 10], ["Vesper Bay", -90, 20], ["Scorpion Crossing", 40, -50], ["The Silver Bazaar", -40, 60]]},
		"central_thanalan": {"name": "Central Thanalan", "region": "Thanalan", "type": "field", "biome": "desert", "lvl": [3, 10], "aetheryte": "Black Brush Station",
			"exits": [{"to": "uldah", "dir": "SW"}, {"to": "western_thanalan", "dir": "W"}, {"to": "northern_thanalan", "dir": "N"}, {"to": "eastern_thanalan", "dir": "E"}, {"to": "southern_thanalan", "dir": "S"}],
			"mobs": [["antling", 5], ["cactuar", 4], ["yarzon", 3], ["bandit", 3], ["bandit_archer", 2]], "hunts": ["coeurl", "adamantoise"], "water": "lake",
			"landmarks": [["Black Brush Station", 0, 0], ["Spineless Basin", -40, 50], ["Lost Hope", 60, -40]]},
		"eastern_thanalan": {"name": "Eastern Thanalan", "region": "Thanalan", "type": "field", "biome": "desert", "lvl": [12, 18], "aetheryte": "Camp Drybone",
			"exits": [{"to": "central_thanalan", "dir": "W"}, {"to": "southern_thanalan", "dir": "S"}, {"to": "south_shroud", "dir": "NE"}],
			"mobs": [["yarzon", 5], ["cactuar", 4], ["bomb", 3]], "hunts": ["adamantoise"], "water": "river",
			"landmarks": [["Camp Drybone", -10, 20], ["Highbridge", 50, -10], ["The Golden Bazaar", -60, -50]]},
		"southern_thanalan": {"name": "Southern Thanalan", "region": "Thanalan", "type": "field", "biome": "desert", "lvl": [16, 24], "aetheryte": "Little Ala Mhigo",
			"exits": [{"to": "eastern_thanalan", "dir": "N"}, {"to": "central_thanalan", "dir": "NW"}],
			"mobs": [["yarzon", 5], ["bomb", 5], ["cactuar", 3]], "hunts": ["adamantoise"], "water": "",
			"landmarks": [["Little Ala Mhigo", -20, -10], ["Forgotten Springs", 40, 60], ["Zahar'ak", 60, -60]]},
		"northern_thanalan": {"name": "Northern Thanalan", "region": "Thanalan", "type": "field", "biome": "desert", "lvl": [18, 24], "aetheryte": "Camp Bluefog",
			"exits": [{"to": "central_thanalan", "dir": "S"}, {"to": "mor_dhona", "dir": "N"}],
			"mobs": [["coblyn", 5], ["bomb", 5], ["yarzon", 3]], "hunts": ["adamantoise", "behemoth"], "water": "",
			"landmarks": [["Camp Bluefog", 0, 20], ["Ceruleum Processing Plant", 50, -30], ["Raubahn's Push", -50, -50]]},
		# ======================= COERTHAS & MOR DHONA
		"coerthas_central": {"name": "Coerthas Central Highlands", "region": "Coerthas", "type": "field", "biome": "snow", "lvl": [1, 24], "aetheryte": "Camp Dragonhead",
			"exits": [{"to": "ishgard", "dir": "N"}, {"to": "north_shroud", "dir": "S"}, {"to": "mor_dhona", "dir": "SW"}],
			"mobs": [["wolf", 5], ["karakul", 4], ["sprite", 4], ["marmot", 2]], "hunts": ["wyvern", "behemoth"], "water": "lake",
			"landmarks": [["Camp Dragonhead", 0, 10], ["Whitebrim Front", 30, -60], ["The Steel Vigil", 70, 20], ["Witchdrop", -60, -40]]},
		"mor_dhona": {"name": "Mor Dhona", "region": "Mor Dhona", "type": "field", "biome": "crystal", "lvl": [18, 26], "aetheryte": "Revenant's Toll",
			"exits": [{"to": "coerthas_central", "dir": "NE"}, {"to": "northern_thanalan", "dir": "SW"}],
			"mobs": [["sprite", 5], ["coblyn", 5], ["wolf", 3]], "hunts": ["behemoth", "wyvern"], "water": "lake",
			"landmarks": [["Revenant's Toll", 0, 0], ["Silvertear Lake", 60, -40], ["The Crystal Tower", -70, -70], ["Castrum Centri", 60, 60]]},
	}


## Opening location for each starting city: the road just outside it.
const STARTS := {
	"gridania": {"zone": "central_shroud", "pos": Vector3(-2, 0, -100), "villager": "Eluned, a Bentbranch herder", "villager_look": ["hyur", "midlander", "f"]},
	"limsa": {"zone": "middle_la_noscea", "pos": Vector3(-85, 0, 85), "villager": "Wulfric, a Summerford farmhand", "villager_look": ["roegadyn", "sea_wolf", "m"]},
	"uldah": {"zone": "western_thanalan", "pos": Vector3(95, 0, 0), "villager": "Yayasha, a Horizon water-seller", "villager_look": ["lalafell", "dunesfolk", "f"]},
	"ishgard": {"zone": "coerthas_central", "pos": Vector3(0, 0, -100), "villager": "Brother Aurmont, a Dragonhead lay brother", "villager_look": ["elezen", "wildwood", "m"]},
}

const DIRS := {"N": Vector2(0, -1), "S": Vector2(0, 1), "E": Vector2(1, 0), "W": Vector2(-1, 0),
	"NE": Vector2(0.7071, -0.7071), "NW": Vector2(-0.7071, -0.7071), "SE": Vector2(0.7071, 0.7071), "SW": Vector2(-0.7071, 0.7071)}
