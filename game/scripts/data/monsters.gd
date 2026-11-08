class_name MonsterData
## Bestiary. body: procedural rig used by MonsterBuilder. Attacks are telegraphed
## (wind-up animation plus a ground marker) and hit hard.
## attack: name, shape (circle|cone|line|donut|self|charge|leap|proj|combo), wind (s), dmg, range, arc/width, cd, anim, phase(0/1)

static func a(name: String, shape: String, wind: float, dmg: float, rng: float, x := {}) -> Dictionary:
	var d := {"name": name, "shape": shape, "wind": wind, "dmg": dmg, "range": rng, "arc": 90.0, "width": 2.0,
		"cd": 3.0, "anim": "swipe", "phase": 0, "knock": 4.0, "weight": 1.0}
	for k in x: d[k] = x[k]
	return d


static func all() -> Dictionary:
	return {
		# ---------------- small: Black Shroud
		"squirrel": {"name": "Ground Squirrel", "body": "quad", "size": 0.45, "col": "#8a6a4a", "col2": "#d8c0a0", "hp": 70, "atk": 6, "lvl": 1, "speed": 4.5,
			"drops": {"beast_hide": 0.5}, "attacks": [a("Bite", "cone", 0.6, 1.0, 1.4, {"arc": 70.0, "anim": "bite"})]},
		"funguar": {"name": "Forest Funguar", "body": "plant", "size": 0.7, "col": "#c8a070", "col2": "#a04030", "hp": 110, "atk": 8, "lvl": 2, "speed": 2.5,
			"drops": {"mandrake_root": 0.6}, "attacks": [a("Spore Sac", "circle", 1.2, 1.2, 3.0, {"anim": "slam", "self": true}), a("Headbutt", "cone", 0.6, 1.0, 1.6, {"anim": "bite"})]},
		"boar": {"name": "Wild Boar", "body": "quad", "size": 0.9, "col": "#5a4232", "col2": "#c8b8a0", "tusks": true, "hp": 180, "atk": 11, "lvl": 4, "speed": 6.0,
			"drops": {"beast_hide": 0.8}, "attacks": [a("Gore", "charge", 1.0, 1.5, 9.0, {"width": 1.6, "anim": "charge", "cd": 5.0}), a("Tusk Toss", "cone", 0.7, 1.1, 2.0, {"anim": "bite"})]},
		"ladybug": {"name": "Little Ladybug", "body": "insect", "size": 0.55, "col": "#c02020", "col2": "#101010", "hp": 80, "atk": 7, "lvl": 1, "speed": 3.5, "fly": 1.2,
			"drops": {"wind_shard": 0.7}, "attacks": [a("Sticky Thread", "proj", 1.0, 1.0, 14.0, {"anim": "spit", "color": "#e0e0e0"})]},
		"treant": {"name": "Treant Sapling", "body": "plant", "size": 1.1, "col": "#5a4a2a", "col2": "#4a7a2a", "branches": true, "hp": 260, "atk": 13, "lvl": 6, "speed": 2.0,
			"drops": {"latex": 0.7}, "attacks": [a("Root Lash", "line", 1.1, 1.4, 7.0, {"width": 1.8, "anim": "slam"}), a("Leaf Storm", "circle", 1.4, 1.2, 4.0, {"self": true, "anim": "spin"})]},
		# ---------------- small: La Noscea
		"pugil": {"name": "Pugil", "body": "biped", "size": 0.7, "col": "#4a8a7a", "col2": "#c8e0c0", "fishy": true, "hp": 120, "atk": 9, "lvl": 2, "speed": 4.0,
			"drops": {"pugil_scale": 0.8}, "attacks": [a("Water Cannon", "line", 1.1, 1.2, 8.0, {"width": 1.2, "anim": "spit", "elem": "water"}), a("Fin Slap", "cone", 0.6, 1.0, 1.6)]},
		"dodo": {"name": "Wild Dodo", "body": "bird", "size": 0.9, "col": "#d8c8a0", "col2": "#c86030", "hp": 150, "atk": 10, "lvl": 3, "speed": 5.5,
			"drops": {"beast_hide": 0.6}, "attacks": [a("Peck", "cone", 0.6, 1.0, 1.8, {"anim": "bite"}), a("Stampede", "charge", 1.0, 1.3, 8.0, {"anim": "charge", "cd": 6.0})]},
		"bomb": {"name": "Bomb", "body": "blob", "size": 0.8, "col": "#ff7020", "col2": "#ffd040", "glow": true, "hp": 140, "atk": 12, "lvl": 5, "speed": 3.5, "fly": 1.0,
			"drops": {"bomb_ash": 0.8, "fire_shard": 0.6}, "attacks": [a("Self-Destruct", "circle", 2.6, 3.5, 5.0, {"self": true, "anim": "swell", "cd": 99.0, "suicide": true, "phase": 1, "elem": "fire"}), a("Burning Rush", "charge", 0.9, 1.2, 7.0, {"anim": "charge"})]},
		"coblyn": {"name": "Coblyn", "body": "blob", "size": 0.75, "col": "#8a8070", "col2": "#40d0ff", "rocky": true, "hp": 220, "atk": 12, "lvl": 6, "speed": 2.5,
			"drops": {"iron_ore": 0.7, "copper_ore": 0.5}, "attacks": [a("Rock Throw", "proj", 1.0, 1.3, 16.0, {"anim": "spit", "color": "#8a8070", "aoe": 2.0}), a("Slam", "circle", 1.1, 1.4, 2.8, {"self": true, "anim": "slam"})]},
		# ---------------- small: Thanalan
		"cactuar": {"name": "Cactuar", "body": "cactuar", "size": 0.6, "col": "#6aa040", "col2": "#f0e080", "hp": 100, "atk": 10, "lvl": 3, "speed": 7.0,
			"drops": {"cactuar_needle": 0.9}, "attacks": [a("1,000 Needles", "circle", 1.6, 2.0, 6.0, {"self": true, "anim": "spin", "cd": 8.0}), a("Kick", "cone", 0.5, 1.0, 1.5)]},
		"antling": {"name": "Antling Worker", "body": "insect", "size": 0.6, "col": "#a05a2a", "col2": "#40200a", "hp": 110, "atk": 9, "lvl": 2, "speed": 4.0,
			"drops": {"copper_ore": 0.4, "beast_hide": 0.3}, "attacks": [a("Mandibles", "cone", 0.6, 1.1, 1.6, {"anim": "bite"})]},
		"marmot": {"name": "Star Marmot", "body": "quad", "size": 0.5, "col": "#b08a5a", "col2": "#f0e0c0", "hp": 75, "atk": 7, "lvl": 1, "speed": 5.0,
			"drops": {"beast_hide": 0.5}, "attacks": [a("Gnaw", "cone", 0.5, 1.0, 1.4, {"anim": "bite"})]},
		"yarzon": {"name": "Yarzon Scavenger", "body": "insect", "size": 0.85, "col": "#c8a060", "col2": "#6a4020", "hp": 200, "atk": 12, "lvl": 5, "speed": 3.5,
			"drops": {"beast_hide": 0.6, "silver_ore": 0.3}, "attacks": [a("Claw Combo", "combo", 0.6, 0.9, 2.0, {"hits": 3}), a("Acid Spit", "proj", 1.0, 1.2, 14.0, {"anim": "spit", "color": "#a0ff40", "aoe": 2.0})]},
		# ---------------- small: Coerthas & Mor Dhona
		"wolf": {"name": "Snow Wolf", "body": "quad", "size": 0.85, "col": "#e8eef2", "col2": "#8a9aa8", "hp": 230, "atk": 14, "lvl": 8, "speed": 7.0,
			"drops": {"beast_hide": 0.8, "ice_shard": 0.5}, "attacks": [a("Lunge Bite", "leap", 0.8, 1.4, 7.0, {"anim": "leap", "range_aoe": 2.0}), a("Frost Breath", "cone", 1.2, 1.3, 5.0, {"arc": 60.0, "anim": "spit", "elem": "ice"})]},
		"karakul": {"name": "Ornery Karakul", "body": "quad", "size": 0.9, "col": "#e8e0d0", "col2": "#6a5040", "horns": true, "hp": 260, "atk": 14, "lvl": 9, "speed": 5.5,
			"drops": {"aldgoat_horn": 0.6, "beast_hide": 0.6}, "attacks": [a("Rush", "charge", 1.0, 1.5, 9.0, {"anim": "charge"}), a("Headbutt", "cone", 0.7, 1.3, 2.0, {"anim": "bite"})]},
		"sprite": {"name": "Ice Sprite", "body": "blob", "size": 0.6, "col": "#a0e0ff", "col2": "#ffffff", "glow": true, "crystal": true, "hp": 180, "atk": 15, "lvl": 9, "speed": 3.0, "fly": 1.6,
			"drops": {"ice_shard": 1.0, "materia_shard": 0.1}, "attacks": [a("Blizzard", "circle", 1.4, 1.4, 3.0, {"anim": "spit", "target": true, "elem": "ice"}), a("Frost Ray", "proj", 0.9, 1.1, 18.0, {"anim": "spit", "color": "#c0f0ff"})]},
		"bandit": {"name": "Highway Bandit", "body": "humanoid", "size": 1.0, "col": "#5a4a3a", "col2": "#8a2a20", "hp": 240, "atk": 13, "lvl": 4, "speed": 5.0,
			"drops": {"iron_ore": 0.3, "materia_shard": 0.05}, "gil": 40, "attacks": [a("Slash Combo", "combo", 0.6, 1.0, 2.2, {"hits": 2}), a("Overhead Chop", "cone", 1.0, 1.6, 2.6, {"arc": 50.0, "anim": "slam"})]},
		"bandit_archer": {"name": "Bandit Archer", "body": "humanoid", "size": 1.0, "col": "#4a5a3a", "col2": "#6a3a20", "ranged": true, "hp": 170, "atk": 12, "lvl": 4, "speed": 4.5,
			"drops": {"beast_hide": 0.3}, "gil": 40, "attacks": [a("Arrow", "proj", 0.9, 1.1, 22.0, {"anim": "spit", "color": "#e0d0b0"}), a("Volley", "circle", 1.6, 1.3, 4.0, {"target": true, "anim": "roar"})]},
		"cultist": {"name": "Unsung Zealot", "body": "humanoid", "size": 1.0, "col": "#3a2a4a", "col2": "#2a2030", "ranged": true, "weapon": "rod", "hp": 230, "atk": 14, "lvl": 12, "speed": 4.5,
			"drops": {"materia_shard": 0.15, "ice_shard": 0.5}, "gil": 60, "attacks": [a("Hymn of Sorrow", "proj", 1.0, 1.2, 20.0, {"anim": "spit", "color": "#9a60ff", "aoe": 2.0}), a("Lament", "circle", 1.6, 1.5, 3.5, {"target": true, "anim": "roar"})]},
		# ---------------- LARGE MONSTERS (Hunts)
		"coeurl": {"name": "Thunderclap Coeurl", "large": true, "body": "quad", "size": 2.6, "col": "#d8a850", "col2": "#3a2a1a", "whiskers": true, "spots": true, "hp": 4200, "atk": 26, "lvl": 10, "speed": 8.5,
			"drops": {"coeurl_fur": 1.0, "iron_ore": 0.7, "materia_shard": 0.6}, "break": {"part": "whiskers", "drop": "coeurl_fur"}, "attacks": [
				a("Claw Rake", "combo", 0.7, 1.2, 3.6, {"hits": 3, "weight": 2.0}),
				a("Pounce", "leap", 1.1, 2.0, 14.0, {"anim": "leap", "range_aoe": 4.0}),
				a("Static Charge", "circle", 1.8, 2.2, 7.0, {"self": true, "anim": "roar", "elem": "lightning"}),
				a("Blaster", "line", 1.3, 2.4, 16.0, {"width": 3.0, "anim": "spit", "elem": "lightning"}),
				a("Electric Whorl", "donut", 1.9, 2.6, 14.0, {"inner": 5.0, "anim": "spin", "phase": 1, "elem": "lightning"}),
			]},
		"morbol": {"name": "Ancient Morbol", "large": true, "body": "plant", "size": 2.8, "col": "#4a7a30", "col2": "#c05050", "tentacles": true, "hp": 5200, "atk": 24, "lvl": 12, "speed": 2.6,
			"drops": {"morbol_vine": 1.0, "mythril_ore": 0.6, "materia_shard": 0.7}, "break": {"part": "tentacles", "drop": "morbol_vine"}, "attacks": [
				a("Vine Sweep", "cone", 1.2, 1.6, 8.0, {"arc": 150.0, "weight": 2.0}),
				a("Bad Breath", "cone", 2.0, 2.0, 12.0, {"arc": 90.0, "anim": "roar", "poison": true}),
				a("Root Eruption", "circle", 1.5, 1.8, 3.5, {"target": true, "anim": "slam", "count": 3}),
				a("Tentacle Slam", "line", 1.1, 2.2, 12.0, {"width": 2.5, "anim": "slam"}),
				a("Putrid Bloom", "circle", 2.4, 3.0, 10.0, {"self": true, "anim": "swell", "phase": 1}),
			]},
		"pugil_great": {"name": "Great Buccaneer Pugil", "large": true, "body": "biped", "size": 2.6, "col": "#2a6a6a", "col2": "#e0d080", "fishy": true, "hp": 4600, "atk": 24, "lvl": 10, "speed": 5.0,
			"drops": {"pugil_scale": 1.0, "silver_ore": 0.6, "materia_shard": 0.6}, "break": {"part": "fin", "drop": "pugil_scale"}, "attacks": [
				a("Fin Flurry", "combo", 0.7, 1.2, 3.8, {"hits": 3, "weight": 2.0}),
				a("Tidal Cannon", "line", 1.4, 2.4, 18.0, {"width": 3.2, "anim": "spit", "elem": "water"}),
				a("Belly Slam", "leap", 1.3, 2.4, 12.0, {"anim": "leap", "range_aoe": 5.0}),
				a("Whirlpool", "donut", 1.8, 2.4, 13.0, {"inner": 4.5, "anim": "spin", "phase": 1, "elem": "water"}),
			]},
		"adamantoise": {"name": "Sandstone Adamantoise", "large": true, "body": "quad", "size": 3.4, "col": "#8a7a5a", "col2": "#c8b070", "shell": true, "hp": 6800, "atk": 26, "lvl": 14, "speed": 2.2,
			"drops": {"silver_ore": 1.0, "mythril_ore": 0.8, "materia_shard": 0.7}, "break": {"part": "shell", "drop": "mythril_ore"}, "defense": 0.25, "attacks": [
				a("Shell Stomp", "circle", 1.4, 2.2, 6.0, {"self": true, "anim": "slam", "weight": 2.0}),
				a("Quake", "circle", 2.2, 2.6, 4.0, {"target": true, "count": 4, "anim": "roar"}),
				a("Spinning Shell", "charge", 1.5, 2.6, 16.0, {"width": 4.0, "anim": "spin"}),
				a("Stone Breath", "cone", 1.6, 2.4, 12.0, {"arc": 60.0, "anim": "spit", "phase": 1}),
			]},
		"wyvern": {"name": "Riven Wyvern", "large": true, "body": "wyvern", "size": 2.8, "col": "#5a6a8a", "col2": "#c0c8d8", "hp": 7400, "atk": 30, "lvl": 18, "speed": 7.0,
			"drops": {"wyvern_wing": 1.0, "cobalt_ore": 0.8, "materia_shard": 0.8}, "break": {"part": "wings", "drop": "wyvern_wing"}, "attacks": [
				a("Tail Sweep", "cone", 1.0, 1.8, 7.0, {"arc": 200.0, "anim": "spin", "weight": 2.0, "behind": true}),
				a("Frost Breath", "cone", 1.6, 2.4, 16.0, {"arc": 50.0, "anim": "spit", "elem": "ice"}),
				a("Dive Bomb", "leap", 1.6, 3.0, 22.0, {"anim": "leap", "range_aoe": 6.0}),
				a("Wing Gale", "circle", 1.8, 2.2, 9.0, {"self": true, "anim": "roar"}),
				a("Glacial Rain", "circle", 2.0, 2.4, 4.0, {"target": true, "count": 5, "anim": "roar", "phase": 1, "elem": "ice"}),
			]},
		"behemoth": {"name": "Behemoth", "large": true, "body": "quad", "size": 3.8, "col": "#5a3a6a", "col2": "#e0d8c0", "horns": true, "mane": true, "hp": 12000, "atk": 36, "lvl": 22, "speed": 6.0,
			"drops": {"behemoth_horn": 1.0, "adamantite_ore": 0.7, "dragon_scale": 0.5, "materia_shard": 1.0}, "break": {"part": "horns", "drop": "behemoth_horn"}, "attacks": [
				a("Heave", "combo", 0.9, 1.6, 4.5, {"hits": 2, "weight": 2.0}),
				a("Charge", "charge", 1.3, 2.8, 22.0, {"width": 4.0, "anim": "charge"}),
				a("Thunder Storm", "circle", 1.8, 2.4, 4.5, {"target": true, "count": 5, "anim": "roar", "elem": "lightning"}),
				a("Meteor", "circle", 4.0, 6.0, 30.0, {"self": true, "anim": "roar", "phase": 1, "cd": 30.0, "los": true}),
				a("Ecliptic Meteor", "donut", 2.2, 3.0, 18.0, {"inner": 6.0, "anim": "spin", "phase": 1}),
			]},
		"bandit_chief": {"name": "Gerolt the Grasping", "large": true, "body": "humanoid", "size": 1.25, "col": "#3a2a2a", "col2": "#c8a040", "hp": 3800, "atk": 22, "lvl": 9, "speed": 6.0,
			"drops": {"materia_shard": 1.0, "iron_ore": 1.0}, "gil": 1500, "attacks": [
				a("Cleaving Combo", "combo", 0.6, 1.2, 3.0, {"hits": 3, "weight": 2.0}),
				a("Lunging Strike", "charge", 0.9, 1.8, 10.0, {"width": 1.8, "anim": "charge"}),
				a("Smoke Bomb", "circle", 1.4, 1.2, 5.0, {"self": true, "anim": "roar", "blink": true}),
				a("Firebomb Volley", "circle", 1.6, 1.8, 3.0, {"target": true, "count": 3, "anim": "spit", "elem": "fire", "phase": 1}),
			]},
	}
