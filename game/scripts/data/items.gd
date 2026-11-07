class_name ItemData
## Equipment tiers, materia, materials, consumables and meals.

const WEAPON_TIERS := [
	{"name": "Weathered", "atk": 10, "slots": 1, "cost": 0, "mats": {}},
	{"name": "Bronze", "atk": 18, "slots": 1, "cost": 400, "mats": {"copper_ore": 3, "fire_shard": 2}},
	{"name": "Iron", "atk": 28, "slots": 2, "cost": 1200, "mats": {"iron_ore": 4, "beast_hide": 2, "fire_shard": 4}},
	{"name": "Steel", "atk": 40, "slots": 2, "cost": 3000, "mats": {"iron_ore": 6, "coeurl_fur": 2, "fire_crystal": 2}},
	{"name": "Mythril", "atk": 55, "slots": 3, "cost": 7000, "mats": {"mythril_ore": 5, "morbol_vine": 2, "fire_crystal": 4}},
	{"name": "Cobalt", "atk": 72, "slots": 3, "cost": 14000, "mats": {"cobalt_ore": 6, "wyvern_wing": 2, "behemoth_horn": 1}},
	{"name": "Adamantite", "atk": 92, "slots": 4, "cost": 30000, "mats": {"adamantite_ore": 6, "dragon_scale": 3, "behemoth_horn": 2}},
]

const WEAPON_NAMES := {
	"sword_shield": "Gladius & Kite Shield", "greataxe": "Labrys", "greatsword": "Claymore", "gunblade": "Gunblade",
	"cane": "Cane", "codex": "Codex", "star_globe": "Star Globe", "nouliths": "Nouliths", "fists": "Knuckles",
	"lance": "Spear", "daggers": "Baselards", "katana": "Uchigatana", "scythe": "War Scythe", "bow": "Longbow",
	"gun": "Arquebus", "chakrams": "Chakrams", "rod": "Rod", "grimoire": "Grimoire", "rapier": "Rapier & Focus",
}

## Armour sets. slot visuals: head=cap, body=tops, legs=bottoms, feet=shoes.
const ARMOR_SETS := [
	{"id": "hempen", "name": "Hempen", "def": 4, "color": "#c9b89a", "metal": 0.0, "rough": 0.95, "cost": 0, "mats": {}},
	{"id": "leather", "name": "Leather", "def": 9, "color": "#8a5a3a", "metal": 0.0, "rough": 0.7, "cost": 600, "mats": {"beast_hide": 3}},
	{"id": "bronze", "name": "Bronze", "def": 15, "color": "#b07a45", "metal": 0.85, "rough": 0.4, "cost": 1500, "mats": {"copper_ore": 5, "beast_hide": 2}},
	{"id": "iron", "name": "Iron", "def": 22, "color": "#8f949a", "metal": 0.9, "rough": 0.35, "cost": 3500, "mats": {"iron_ore": 6, "coeurl_fur": 2}},
	{"id": "mythril", "name": "Mythril", "def": 31, "color": "#c8dcec", "metal": 0.95, "rough": 0.25, "cost": 8000, "mats": {"mythril_ore": 6, "morbol_vine": 2}},
	{"id": "cobalt", "name": "Cobalt", "def": 41, "color": "#4f6fa8", "metal": 0.9, "rough": 0.3, "cost": 16000, "mats": {"cobalt_ore": 6, "wyvern_wing": 2}},
	{"id": "adamantite", "name": "Adamantite", "def": 53, "color": "#3a4a3e", "metal": 0.9, "rough": 0.3, "cost": 32000, "mats": {"adamantite_ore": 6, "dragon_scale": 2}},
]
const ARMOR_SLOTS := {"head": "Head", "body": "Body", "legs": "Legs", "feet": "Feet"}

const MATERIA := {
	"might": {"name": "Savage Might Materia", "stat": "dmg", "per": 0.03},
	"aim": {"name": "Savage Aim Materia", "stat": "crit", "per": 0.025},
	"quick": {"name": "Quickarm Materia", "stat": "haste", "per": 0.02},
	"battle": {"name": "Battledance Materia", "stat": "stam", "per": 0.05},
	"piety": {"name": "Piety Materia", "stat": "mp", "per": 0.05},
	"vit": {"name": "Vitality Materia", "stat": "hp", "per": 0.04},
}
const MATERIA_GRADES := ["I", "II", "III", "IV", "V"]

const MATERIALS := {
	"copper_ore": {"name": "Copper Ore", "price": 12}, "iron_ore": {"name": "Iron Ore", "price": 25},
	"mythril_ore": {"name": "Mythril Ore", "price": 60}, "cobalt_ore": {"name": "Cobalt Ore", "price": 110},
	"adamantite_ore": {"name": "Adamantite Ore", "price": 240},
	"fire_shard": {"name": "Fire Shard", "price": 6}, "fire_crystal": {"name": "Fire Crystal", "price": 40},
	"beast_hide": {"name": "Beast Hide", "price": 15}, "coeurl_fur": {"name": "Coeurl Fur", "price": 70},
	"morbol_vine": {"name": "Morbol Vine", "price": 90}, "wyvern_wing": {"name": "Wyvern Wing", "price": 160},
	"behemoth_horn": {"name": "Behemoth Horn", "price": 400}, "dragon_scale": {"name": "Dragon Scale", "price": 300},
	"pugil_scale": {"name": "Pugil Scale", "price": 20}, "cactuar_needle": {"name": "Cactuar Needle", "price": 30},
	"aldgoat_horn": {"name": "Aldgoat Horn", "price": 35}, "bomb_ash": {"name": "Bomb Ash", "price": 25},
	"mandrake_root": {"name": "Mandrake", "price": 18}, "rolanberry": {"name": "Rolanberry", "price": 10},
	"latex": {"name": "Latex", "price": 15}, "silver_ore": {"name": "Silver Ore", "price": 45},
	"ice_shard": {"name": "Ice Shard", "price": 6}, "wind_shard": {"name": "Wind Shard", "price": 6},
	"materia_shard": {"name": "Faded Materia Fragment", "price": 50},
}

const CONSUMABLES := {
	"potion": {"name": "Hi-Potion", "heal": 0.4, "price": 80, "time": 1.1},
	"ether": {"name": "Hi-Ether", "mp": 4000, "price": 140, "time": 1.1},
	"elixir": {"name": "Elixir", "heal": 1.0, "mp": 10000, "price": 900, "time": 1.4},
	"phoenix": {"name": "Phoenix Down", "revive": true, "price": 600, "time": 0.0},
}

## Meals: main dish = offence & vitality, side = defence & resistance, drink = stamina/mana & mobility.
const MEAL_SLOTS := {"main": "Main Dish", "side": "Side Dish", "drink": "Drink"}
const MEALS := {
	"main": [
		{"id": "dodo_omelette", "name": "Dodo Omelette", "price": 60, "fx": {"hp": 0.08}, "desc": "Max HP +8%"},
		{"id": "mutton_stew", "name": "Mutton Stew", "price": 120, "fx": {"hp": 0.12, "dmg": 0.03}, "desc": "Max HP +12%, damage +3%"},
		{"id": "archon_burger", "name": "Archon Burger", "price": 220, "fx": {"dmg": 0.08}, "desc": "Damage +8%"},
		{"id": "jerked_jhammel", "name": "Jerked Jhammel", "price": 180, "fx": {"crit": 0.06}, "desc": "Critical rate +6%"},
		{"id": "tuna_miqabob", "name": "Tuna Miq'abob", "price": 320, "fx": {"dmg": 0.06, "crit": 0.04}, "desc": "Damage +6%, critical +4%"},
		{"id": "pixieberry_tart", "name": "Pixieberry Tart", "price": 400, "fx": {"hp": 0.1, "mp": 0.1, "dmg": 0.04}, "desc": "HP/MP +10%, damage +4%"},
	],
	"side": [
		{"id": "spinach_saute", "name": "Spinach Sauté", "price": 40, "fx": {"def": 0.06}, "desc": "Defence +6%"},
		{"id": "baked_eggplant", "name": "Baked Eggplant", "price": 90, "fx": {"def": 0.08, "res_fire": 0.2}, "desc": "Defence +8%, fire resistance"},
		{"id": "popoto_salad", "name": "Popoto Salad", "price": 110, "fx": {"def": 0.05, "res_ice": 0.25}, "desc": "Defence +5%, ice resistance"},
		{"id": "chilled_popoto_soup", "name": "Chilled Popoto Soup", "price": 140, "fx": {"stagger_res": 0.3}, "desc": "Resist being staggered"},
		{"id": "rolanberry_cheesecake", "name": "Rolanberry Cheesecake", "price": 260, "fx": {"def": 0.12, "regen": 0.004}, "desc": "Defence +12%, slow regeneration"},
		{"id": "royal_eggs", "name": "Royal Eggs", "price": 300, "fx": {"def": 0.1, "res_all": 0.1}, "desc": "Defence +10%, all resistances"},
	],
	"drink": [
		{"id": "mulled_tea", "name": "Mulled Tea", "price": 30, "fx": {"stam": 0.15}, "desc": "Max stamina +15%"},
		{"id": "orange_juice", "name": "Orange Juice", "price": 50, "fx": {"stam_regen": 0.2}, "desc": "Stamina recovers 20% faster"},
		{"id": "chamomile_tea", "name": "Chamomile Tea", "price": 70, "fx": {"mp_regen": 0.3}, "desc": "MP recovers 30% faster"},
		{"id": "rolanberry_lassi", "name": "Rolanberry Lassi", "price": 120, "fx": {"stam": 0.1, "swim": 0.4}, "desc": "Stamina +10%, longer breath when diving"},
		{"id": "cider", "name": "Cider", "price": 150, "fx": {"haste": 0.06}, "desc": "Action speed +6%"},
		{"id": "coerthan_tea", "name": "Coerthan Tea", "price": 200, "fx": {"res_ice": 0.3, "stam": 0.15, "mp_regen": 0.2}, "desc": "Ice resistance, stamina +15%, MP regen +20%"},
	],
}

## Party members the guild can introduce (recruited with gil and level gates).
const RECRUITS := [
	{"id": "lyse_ar", "name": "Aerith Brightblade", "job": "PLD", "race": "hyur", "clan": "midlander", "sex": "f", "level": 3, "cost": 1500, "hair": "#c9a26b"},
	{"id": "pawpo", "name": "Pawpo Rokopo", "job": "WHM", "race": "lalafell", "clan": "plainsfolk", "sex": "m", "level": 5, "cost": 2500, "hair": "#e8d5a6"},
	{"id": "rhyrn", "name": "R'hyrn Tia", "job": "BRD", "race": "miqote", "clan": "seeker", "sex": "m", "level": 8, "cost": 4000, "hair": "#7a1f1f"},
	{"id": "eadric", "name": "Eadric Moonstride", "job": "DRG", "race": "elezen", "clan": "wildwood", "sex": "m", "level": 12, "cost": 6000, "hair": "#f2f0ea"},
	{"id": "sorai", "name": "Sorai Dotharl", "job": "SCH", "race": "aura", "clan": "xaela", "sex": "f", "level": 15, "cost": 8000, "hair": "#1d1a1a"},
	{"id": "brenna", "name": "Brennagh Thorwyn", "job": "WAR", "race": "roegadyn", "clan": "sea_wolf", "sex": "f", "level": 18, "cost": 10000, "hair": "#c0482d"},
]
