class_name JobData
## Jobs play like Monster Hunter / Elden Ring weapon types. Every job has:
##  - a light chain (Light button), a heavy branch (Heavy button) usable from any combo step,
##    a weapon special (Special button) and four cooldown job actions,
##  - a job gauge that combo steps build and finishers spend.
## Move fields: name, anim, dur (s), cancel (s, when the next input may chain), hits [[start, end, potency, range, arc]],
##  lunge (m), stam, mp, gain (gauge), cost (gauge), alt (move used when gauge is short), armor (hyper armor),
##  iframe [a,b], proj {...}, aoe (radius around self), heal, buff, charge (max hold seconds), elem, cast (s).

const ROLE_NAMES := {"tank": "Tank", "healer": "Healer", "melee": "Melee DPS", "ranged": "Physical Ranged DPS", "caster": "Magical Ranged DPS"}

## city: where the job's story begins (true to where each job's guild/quest lives in FFXIV).
static func all() -> Dictionary:
	return {
		"PLD": _job("Paladin", "tank", "sword_shield", "uldah", "Oath", _pld()),
		"WAR": _job("Warrior", "tank", "greataxe", "limsa", "Beast Gauge", _war()),
		"DRK": _job("Dark Knight", "tank", "greatsword", "ishgard", "Blood Gauge", _drk()),
		"GNB": _job("Gunbreaker", "tank", "gunblade", "gridania", "Powder Gauge", _gnb()),
		"WHM": _job("White Mage", "healer", "cane", "gridania", "Lily Gauge", _whm()),
		"SCH": _job("Scholar", "healer", "codex", "limsa", "Aetherflow", _sch()),
		"AST": _job("Astrologian", "healer", "star_globe", "ishgard", "Arcana", _ast()),
		"SGE": _job("Sage", "healer", "nouliths", "limsa", "Addersgall", _sge()),
		"MNK": _job("Monk", "melee", "fists", "uldah", "Chakra", _mnk()),
		"DRG": _job("Dragoon", "melee", "lance", "gridania", "Firstminds' Focus", _drg()),
		"NIN": _job("Ninja", "melee", "daggers", "limsa", "Ninki", _nin()),
		"SAM": _job("Samurai", "melee", "katana", "uldah", "Kenki", _sam()),
		"RPR": _job("Reaper", "melee", "scythe", "ishgard", "Soul Gauge", _rpr()),
		"BRD": _job("Bard", "ranged", "bow", "gridania", "Soul Voice", _brd()),
		"MCH": _job("Machinist", "ranged", "gun", "ishgard", "Heat Gauge", _mch()),
		"DNC": _job("Dancer", "ranged", "chakrams", "limsa", "Esprit", _dnc()),
		"BLM": _job("Black Mage", "caster", "rod", "uldah", "Astral Fire", _blm()),
		"SMN": _job("Summoner", "caster", "grimoire", "limsa", "Aethertrail", _smn()),
		"RDM": _job("Red Mage", "caster", "rapier", "uldah", "Balance Gauge", _rdm()),
	}


static func _job(n: String, role: String, weapon: String, city: String, gauge: String, kit: Dictionary) -> Dictionary:
	var hp: float = {"tank": 1.35, "healer": 0.95, "melee": 1.05, "ranged": 0.95, "caster": 0.9}[role]
	var d := {"name": n, "role": role, "weapon": weapon, "city": city, "gauge_name": gauge, "hp_mult": hp,
		"guard": role == "tank" or weapon in ["katana", "greatsword", "rapier"], "moves": kit["moves"], "actions": kit["actions"]}
	return d


## Move helper. potency ~ 1.0 = a basic hit.
static func m(name: String, anim: String, dur: float, pot: float, x := {}) -> Dictionary:
	var r: float = x.get("range", 2.6)
	var d := {"name": name, "anim": anim, "dur": dur, "cancel": dur * 0.62, "hits": [[dur * 0.35, dur * 0.55, pot, r, x.get("arc", 120.0)]],
		"lunge": 0.6, "stam": 0.0, "mp": 0, "gain": 0, "cost": 0, "next": {}, "potency": pot}
	if pot <= 0.0: d["hits"] = []
	for k in x: d[k] = x[k]
	return d


static func proj(speed := 32.0, radius := 0.35, color := "#9fd8ff", extra := {}) -> Dictionary:
	var p := {"speed": speed, "radius": radius, "color": color, "homing": 0.0, "aoe": 0.0, "life": 2.2}
	for k in extra: p[k] = extra[k]
	return p


static func act(name: String, kind: String, cd: float, x := {}) -> Dictionary:
	var d := {"name": name, "kind": kind, "cd": cd}
	for k in x: d[k] = x[k]
	return d


# ----------------------------------------------------------------- TANKS
static func _pld() -> Dictionary:
	return {"moves": {
		"L1": m("Fast Blade", "slash_r", 0.42, 1.0, {"next": {"light": "L2"}, "gain": 5}),
		"L2": m("Riot Blade", "slash_l", 0.46, 1.25, {"next": {"light": "L3"}, "gain": 5, "mp": -400}),
		"L3": m("Royal Authority", "slash_down", 0.62, 2.1, {"lunge": 1.2, "gain": 10, "next": {"light": "L1"}}),
		"H": m("Shield Bash", "bash", 0.55, 0.9, {"stagger": 3.0, "range": 2.2, "next": {"light": "L3"}}),
		"H2": m("Prominence", "spin", 0.75, 1.4, {"aoe": 3.4, "hits": [[0.25, 0.5, 1.4, 3.4, 360.0]], "armor": true}),
		"S": m("Holy Spirit", "cast", 0.9, 2.4, {"mp": 1000, "hits": [], "proj": proj(36, 0.45, "#fff6c8", {"aoe": 2.5}), "elem": "light", "heal": 0.08}),
		"guard_counter": m("Sheltron Riposte", "slash_up", 0.5, 2.0, {"cost": 50}),
	}, "actions": [
		act("Fight or Flight", "buff", 45, {"buff": "dmg", "amount": 0.25, "time": 20}),
		act("Rampart", "buff", 60, {"buff": "def", "amount": 0.4, "time": 20}),
		act("Circle of Scorn", "aoe", 20, {"pot": 1.6, "radius": 5.0, "anim": "spin"}),
		act("Intervene", "dash", 15, {"pot": 1.2, "dist": 8.0}),
	]}


static func _war() -> Dictionary:
	return {"moves": {
		"L1": m("Heavy Swing", "heavy_side", 0.62, 1.3, {"range": 3.0, "next": {"light": "L2"}, "gain": 10}),
		"L2": m("Maim", "heavy_side_back", 0.66, 1.5, {"range": 3.0, "next": {"light": "L3"}, "gain": 10}),
		"L3": m("Storm's Path", "heavy_down", 0.85, 2.6, {"range": 3.2, "lunge": 1.4, "heal": 0.06, "gain": 20, "armor": true}),
		"H": m("Fell Cleave", "heavy_down", 0.9, 3.6, {"range": 3.4, "cost": 50, "alt": "H2", "armor": true, "shake": 0.6}),
		"H2": m("Overpower", "spin", 0.85, 1.6, {"aoe": 3.8, "hits": [[0.25, 0.6, 1.6, 3.8, 360.0]], "gain": 10}),
		"S": m("Upheaval", "heavy_up", 0.8, 2.8, {"range": 3.0, "stam": 30.0, "armor": true, "charge": 1.2}),
	}, "actions": [
		act("Inner Release", "buff", 60, {"buff": "crit", "amount": 1.0, "time": 15, "armor": true}),
		act("Thrill of Battle", "heal", 90, {"amount": 0.25}),
		act("Onslaught", "dash", 12, {"pot": 1.3, "dist": 9.0}),
		act("Infuriate", "gauge", 50, {"amount": 50}),
	]}


static func _drk() -> Dictionary:
	return {"moves": {
		"L1": m("Hard Slash", "heavy_side", 0.6, 1.25, {"range": 3.1, "next": {"light": "L2"}}),
		"L2": m("Syphon Strike", "heavy_side_back", 0.62, 1.45, {"range": 3.1, "next": {"light": "L3"}, "mp": -600}),
		"L3": m("Souleater", "heavy_down", 0.82, 2.4, {"range": 3.2, "lunge": 1.3, "gain": 20, "heal": 0.05, "armor": true}),
		"H": m("Bloodspiller", "heavy_up", 0.8, 3.3, {"range": 3.2, "cost": 50, "alt": "H2", "elem": "dark"}),
		"H2": m("Unleash", "spin", 0.8, 1.4, {"aoe": 4.0, "hits": [[0.2, 0.55, 1.4, 4.0, 360.0]], "mp": 300, "elem": "dark"}),
		"S": m("Edge of Shadow", "thrust", 0.7, 2.6, {"mp": 2000, "range": 5.0, "arc": 50.0, "lunge": 3.0, "elem": "dark"}),
	}, "actions": [
		act("The Blackest Night", "shield", 25, {"amount": 0.25, "mp": 2000}),
		act("Blood Weapon", "buff", 60, {"buff": "dmg", "amount": 0.2, "time": 15}),
		act("Salted Earth", "zone", 60, {"pot": 0.45, "radius": 4.0, "time": 12, "color": "#7a2bd0"}),
		act("Plunge", "dash", 20, {"pot": 1.1, "dist": 10.0}),
	]}


static func _gnb() -> Dictionary:
	return {"moves": {
		"L1": m("Keen Edge", "slash_r", 0.45, 1.05, {"next": {"light": "L2"}}),
		"L2": m("Brutal Shell", "slash_l", 0.48, 1.25, {"next": {"light": "L3"}, "heal": 0.03}),
		"L3": m("Solid Barrel", "slash_down", 0.62, 1.9, {"lunge": 1.2, "gain": 34}),
		"H": m("Gnashing Fang", "slash_up", 0.5, 2.0, {"cost": 34, "alt": "H2", "next": {"heavy": "GF2"}, "shake": 0.4}),
		"GF2": m("Savage Claw", "spin", 0.55, 2.2, {"next": {"heavy": "GF3"}, "hits": [[0.15, 0.4, 2.2, 3.0, 300.0]]}),
		"GF3": m("Wicked Talon", "heavy_down", 0.7, 2.8, {"lunge": 1.5, "shake": 0.6}),
		"H2": m("Demon Slice", "spin", 0.65, 1.2, {"aoe": 3.4, "hits": [[0.2, 0.5, 1.2, 3.4, 360.0]], "gain": 15}),
		"S": m("Burst Strike", "thrust", 0.6, 2.6, {"cost": 34, "alt": "H2", "range": 3.2, "arc": 60.0, "lunge": 1.8}),
	}, "actions": [
		act("No Mercy", "buff", 60, {"buff": "dmg", "amount": 0.2, "time": 20}),
		act("Heart of Corundum", "shield", 25, {"amount": 0.2}),
		act("Bow Shock", "aoe", 60, {"pot": 2.2, "radius": 5.0, "anim": "bash"}),
		act("Rough Divide", "dash", 12, {"pot": 1.0, "dist": 9.0}),
	]}


# ----------------------------------------------------------------- HEALERS
static func _whm() -> Dictionary:
	return {"moves": {
		"L1": m("Stone", "cast", 0.55, 1.1, {"hits": [], "proj": proj(30, 0.35, "#e8dcc0"), "next": {"light": "L2"}}),
		"L2": m("Stone II", "cast_l", 0.55, 1.2, {"hits": [], "proj": proj(30, 0.35, "#e8dcc0"), "next": {"light": "L3"}}),
		"L3": m("Glare", "cast_up", 0.8, 2.0, {"hits": [], "proj": proj(40, 0.5, "#ffffff", {"aoe": 2.0}), "mp": 400, "gain": 34}),
		"H": m("Holy", "cast_up", 1.0, 1.6, {"hits": [], "aoe": 6.0, "stagger": 3.0, "mp": 1500, "elem": "light", "nova": "#fff8d0"}),
		"H2": m("Aero", "cast", 0.6, 0.6, {"hits": [], "proj": proj(34, 0.4, "#b6ffd2", {"dot": 0.35}), "mp": 400}),
		"S": m("Afflatus Solace", "heal", 0.7, 0.0, {"heal": 0.35, "cost": 34, "alt": "S2", "party_heal": true}),
		"S2": m("Cure", "heal", 1.0, 0.0, {"heal": 0.22, "mp": 800, "party_heal": true}),
	}, "actions": [
		act("Regen", "regen", 20, {"amount": 0.02, "time": 18}),
		act("Benediction", "heal", 120, {"amount": 1.0}),
		act("Asylum", "zone_heal", 60, {"amount": 0.03, "radius": 5.0, "time": 15, "color": "#a9ffe0"}),
		act("Aetherial Shift", "dash", 30, {"pot": 0.0, "dist": 10.0}),
	]}


static func _sch() -> Dictionary:
	return {"moves": {
		"L1": m("Ruin", "cast", 0.55, 1.05, {"hits": [], "proj": proj(30, 0.35, "#ffe08a"), "next": {"light": "L2"}}),
		"L2": m("Broil", "cast_l", 0.6, 1.35, {"hits": [], "proj": proj(34, 0.4, "#ffd060"), "next": {"light": "L3"}}),
		"L3": m("Ruin II", "cast_up", 0.7, 1.7, {"hits": [], "proj": proj(40, 0.45, "#ffc040", {"aoe": 2.0}), "gain": 34}),
		"H": m("Art of War", "spin", 0.7, 1.5, {"aoe": 5.0, "hits": [[0.25, 0.5, 1.5, 5.0, 360.0]], "mp": 600, "nova": "#ffd060"}),
		"H2": m("Biolysis", "cast", 0.6, 0.5, {"hits": [], "proj": proj(30, 0.35, "#a0ff60", {"dot": 0.45}), "mp": 300}),
		"S": m("Lustrate", "heal", 0.6, 0.0, {"heal": 0.3, "cost": 34, "alt": "S2", "party_heal": true}),
		"S2": m("Adloquium", "heal", 1.0, 0.0, {"heal": 0.15, "shield": 0.15, "mp": 1000, "party_heal": true}),
	}, "actions": [
		act("Whispering Dawn", "regen", 60, {"amount": 0.03, "time": 20}),
		act("Energy Drain", "proj", 6, {"pot": 1.4, "color": "#ffd060", "mp_gain": 500}),
		act("Sacred Soil", "zone_heal", 30, {"amount": 0.02, "radius": 5.0, "time": 15, "color": "#ffe8a0", "def": 0.1}),
		act("Chain Stratagem", "buff", 120, {"buff": "crit", "amount": 0.5, "time": 15}),
	]}


static func _ast() -> Dictionary:
	return {"moves": {
		"L1": m("Malefic", "cast", 0.55, 1.1, {"hits": [], "proj": proj(30, 0.35, "#bfa8ff"), "next": {"light": "L2"}}),
		"L2": m("Malefic II", "cast_l", 0.55, 1.25, {"hits": [], "proj": proj(32, 0.35, "#a890ff"), "next": {"light": "L3"}}),
		"L3": m("Fall Malefic", "cast_up", 0.8, 1.9, {"hits": [], "proj": proj(36, 0.5, "#e0d0ff", {"aoe": 2.2}), "gain": 34}),
		"H": m("Gravity", "cast_up", 0.9, 1.5, {"hits": [], "proj": proj(28, 0.6, "#8060ff", {"aoe": 4.0}), "mp": 700}),
		"H2": m("Combust", "cast", 0.6, 0.5, {"hits": [], "proj": proj(34, 0.3, "#fff0a0", {"dot": 0.45}), "mp": 300}),
		"S": m("Play (The Balance)", "buff_pose", 0.7, 0.0, {"cost": 34, "alt": "S2", "buff": "dmg", "buff_amount": 0.15, "buff_time": 15}),
		"S2": m("Benefic II", "heal", 1.0, 0.0, {"heal": 0.25, "mp": 900, "party_heal": true}),
	}, "actions": [
		act("Aspected Helios", "regen", 30, {"amount": 0.025, "time": 15}),
		act("Earthly Star", "zone_heal", 60, {"amount": 0.04, "radius": 6.0, "time": 10, "color": "#d0c0ff", "pot": 0.3}),
		act("Lightspeed", "buff", 90, {"buff": "haste", "amount": 0.3, "time": 15}),
		act("Essential Dignity", "heal", 40, {"amount": 0.4}),
	]}


static func _sge() -> Dictionary:
	return {"moves": {
		"L1": m("Dosis", "cast", 0.5, 1.1, {"hits": [], "proj": proj(34, 0.3, "#80f0ff"), "next": {"light": "L2"}, "kardia": true}),
		"L2": m("Dosis II", "cast_l", 0.5, 1.25, {"hits": [], "proj": proj(34, 0.3, "#60e0ff"), "next": {"light": "L3"}, "kardia": true}),
		"L3": m("Dosis III", "cast_up", 0.7, 1.8, {"hits": [], "proj": proj(40, 0.45, "#a0ffff", {"aoe": 2.0}), "gain": 34, "kardia": true}),
		"H": m("Phlegma", "thrust", 0.6, 2.2, {"range": 4.0, "arc": 90.0, "lunge": 3.0, "kardia": true, "aoe": 0.0}),
		"H2": m("Dyskrasia", "spin", 0.6, 1.0, {"aoe": 4.5, "hits": [[0.2, 0.45, 1.0, 4.5, 360.0]], "mp": 400}),
		"S": m("Taurochole", "heal", 0.6, 0.0, {"heal": 0.3, "cost": 34, "alt": "S2", "party_heal": true}),
		"S2": m("Eukrasian Diagnosis", "heal", 0.9, 0.0, {"heal": 0.1, "shield": 0.2, "mp": 900, "party_heal": true}),
	}, "actions": [
		act("Icarus", "dash", 20, {"pot": 0.0, "dist": 11.0}),
		act("Pneuma", "beam", 60, {"pot": 3.0, "length": 18.0, "heal": 0.2, "color": "#a0ffff"}),
		act("Kerachole", "zone_heal", 30, {"amount": 0.02, "radius": 5.0, "time": 15, "color": "#a0f0ff", "def": 0.1}),
		act("Toxikon", "proj", 8, {"pot": 1.6, "color": "#40ffd0"}),
	]}


# ----------------------------------------------------------------- MELEE
static func _mnk() -> Dictionary:
	return {"moves": {
		"L1": m("Bootshine", "punch_r", 0.3, 0.8, {"range": 2.0, "next": {"light": "L2"}, "gain": 8, "lunge": 0.5}),
		"L2": m("True Strike", "punch_l", 0.3, 0.9, {"range": 2.0, "next": {"light": "L3"}, "gain": 8, "lunge": 0.5}),
		"L3": m("Snap Punch", "punch_r", 0.34, 1.05, {"range": 2.1, "next": {"light": "L4"}, "gain": 8, "lunge": 0.6}),
		"L4": m("Dragon Kick", "kick", 0.48, 1.6, {"range": 2.4, "next": {"light": "L1"}, "gain": 12, "lunge": 0.8}),
		"H": m("Demolish", "heavy_up", 0.6, 2.2, {"range": 2.4, "lunge": 1.2, "dot": 0.3}),
		"H2": m("Rockbreaker", "slam", 0.7, 1.4, {"aoe": 3.6, "hits": [[0.35, 0.5, 1.4, 3.6, 360.0]]}),
		"S": m("The Forbidden Chakra", "punch_r", 0.6, 3.4, {"cost": 50, "alt": "S2", "range": 3.0, "arc": 50.0, "lunge": 1.5, "shake": 0.6}),
		"S2": m("Steel Peak", "punch_l", 0.45, 1.2, {"range": 2.5, "gain": 10}),
	}, "actions": [
		act("Riddle of Fire", "buff", 60, {"buff": "dmg", "amount": 0.25, "time": 20}),
		act("Thunderclap", "dash", 10, {"pot": 0.8, "dist": 10.0}),
		act("Howling Fist", "beam", 15, {"pot": 1.8, "length": 12.0, "color": "#ffd070"}),
		act("Perfect Balance", "gauge", 40, {"amount": 100}),
	]}


static func _drg() -> Dictionary:
	return {"moves": {
		"L1": m("True Thrust", "thrust", 0.45, 1.05, {"range": 3.4, "arc": 50.0, "next": {"light": "L2"}, "gain": 10}),
		"L2": m("Vorpal Thrust", "thrust", 0.48, 1.25, {"range": 3.4, "arc": 50.0, "next": {"light": "L3"}, "gain": 10}),
		"L3": m("Heavens' Thrust", "thrust_big", 0.72, 2.3, {"range": 3.8, "arc": 50.0, "lunge": 2.0, "gain": 15}),
		"H": m("Chaos Thrust", "slash_up", 0.65, 1.6, {"range": 3.4, "dot": 0.4, "next": {"heavy": "H3"}}),
		"H3": m("Wheeling Thrust", "spin", 0.6, 1.9, {"hits": [[0.2, 0.45, 1.9, 3.4, 360.0]]}),
		"H2": m("Doom Spike", "thrust_big", 0.7, 1.3, {"range": 7.0, "arc": 30.0, "lunge": 2.5}),
		"S": m("Jump", "leap", 1.05, 3.2, {"hits": [[0.7, 0.85, 3.2, 3.2, 360.0]], "iframe": [0.0, 0.75], "lunge": 4.0, "stam": 25.0, "gain": 20, "shake": 0.7}),
	}, "actions": [
		act("Lance Charge", "buff", 60, {"buff": "dmg", "amount": 0.2, "time": 20}),
		act("Spineshatter Dive", "dash", 20, {"pot": 1.8, "dist": 10.0}),
		act("Geirskogul", "beam", 30, {"pot": 2.6, "length": 14.0, "color": "#6a8aff", "cost": 50}),
		act("Dragonfire Dive", "aoe", 90, {"pot": 3.2, "radius": 5.5, "anim": "leap", "color": "#ff6a30"}),
	]}


static func _nin() -> Dictionary:
	return {"moves": {
		"L1": m("Spinning Edge", "slash_r", 0.28, 0.75, {"range": 2.2, "next": {"light": "L2"}, "gain": 5, "lunge": 0.5}),
		"L2": m("Gust Slash", "slash_l", 0.28, 0.85, {"range": 2.2, "next": {"light": "L3"}, "gain": 5, "lunge": 0.5}),
		"L3": m("Aeolian Edge", "spin", 0.5, 1.7, {"hits": [[0.1, 0.35, 1.7, 2.6, 300.0]], "gain": 15, "lunge": 1.0}),
		"H": m("Armor Crush", "slash_down", 0.5, 1.8, {"range": 2.4, "gain": 10}),
		"H2": m("Death Blossom", "spin", 0.5, 0.9, {"aoe": 3.0, "hits": [[0.1, 0.4, 0.9, 3.0, 360.0]]}),
		"S": m("Ninjutsu: Raiton", "mudra", 0.75, 2.6, {"hits": [], "proj": proj(45, 0.4, "#c0a0ff", {"homing": 6.0}), "stam": 20.0, "elem": "lightning"}),
		"S2": m("Ninjutsu: Katon", "mudra", 0.75, 1.8, {"hits": [], "proj": proj(30, 0.7, "#ff7030", {"aoe": 4.0}), "stam": 25.0, "elem": "fire"}),
	}, "actions": [
		act("Shukuchi", "dash", 15, {"pot": 0.0, "dist": 12.0}),
		act("Bhavacakra", "proj", 6, {"pot": 2.0, "color": "#ffb0f0", "cost": 50}),
		act("Mug", "buff", 60, {"buff": "dmg", "amount": 0.15, "time": 20, "gil": 20}),
		act("Ninjutsu: Katon", "special_alt", 12, {"move": "S2"}),
	]}


static func _sam() -> Dictionary:
	return {"moves": {
		"L1": m("Hakaze", "slash_r", 0.42, 1.1, {"next": {"light": "L2"}, "gain": 10}),
		"L2": m("Jinpu", "slash_l", 0.45, 1.3, {"next": {"light": "L3"}, "gain": 10}),
		"L3": m("Gekko", "slash_down", 0.6, 2.0, {"lunge": 1.4, "gain": 15, "sen": 1}),
		"H": m("Shifu", "slash_up", 0.5, 1.3, {"next": {"heavy": "H3"}, "gain": 10}),
		"H3": m("Kasha", "spin", 0.62, 2.0, {"hits": [[0.2, 0.45, 2.0, 3.0, 300.0]], "sen": 1}),
		"H2": m("Yukikaze", "thrust", 0.55, 1.6, {"arc": 60.0, "range": 3.0, "sen": 1}),
		"S": m("Iaijutsu", "iai", 1.0, 1.6, {"hits": [[0.65, 0.8, 1.6, 5.0, 140.0]], "iai": true, "lunge": 2.5, "shake": 0.7}),
	}, "actions": [
		act("Hissatsu: Shinten", "proj", 5, {"pot": 1.8, "color": "#ff4060", "cost": 25, "melee": true}),
		act("Gyoten", "dash", 10, {"pot": 1.0, "dist": 9.0}),
		act("Third Eye", "parry", 15, {"time": 0.8}),
		act("Meikyo Shisui", "gauge", 55, {"sen": 3}),
	]}


static func _rpr() -> Dictionary:
	return {"moves": {
		"L1": m("Slice", "heavy_side", 0.52, 1.15, {"range": 3.2, "arc": 160.0, "next": {"light": "L2"}, "gain": 10}),
		"L2": m("Waxing Slice", "heavy_side_back", 0.55, 1.35, {"range": 3.2, "arc": 160.0, "next": {"light": "L3"}, "gain": 10}),
		"L3": m("Infernal Slice", "spin", 0.75, 2.2, {"hits": [[0.2, 0.55, 2.2, 3.4, 360.0]], "gain": 15}),
		"H": m("Gibbet", "heavy_down", 0.7, 2.8, {"range": 3.3, "cost": 50, "alt": "H2", "elem": "dark"}),
		"H2": m("Soul Slice", "heavy_up", 0.6, 1.8, {"range": 3.2, "gain": 50}),
		"S": m("Harpe", "cast", 0.7, 1.5, {"hits": [], "proj": proj(40, 0.4, "#d050ff"), "elem": "dark"}),
	}, "actions": [
		act("Arcane Circle", "buff", 120, {"buff": "dmg", "amount": 0.2, "time": 20}),
		act("Hell's Ingress", "dash", 20, {"pot": 0.0, "dist": 11.0}),
		act("Grim Swathe", "aoe", 6, {"pot": 1.8, "radius": 4.5, "anim": "spin", "cost": 50}),
		act("Arcane Crest", "shield", 30, {"amount": 0.15}),
	]}


# ----------------------------------------------------------------- PHYSICAL RANGED
static func _brd() -> Dictionary:
	return {"moves": {
		"L1": m("Heavy Shot", "shoot_bow", 0.38, 0.95, {"hits": [], "proj": proj(60, 0.2, "#e8ffd0"), "next": {"light": "L2"}, "gain": 5, "lunge": 0.0}),
		"L2": m("Straight Shot", "shoot_bow", 0.38, 1.05, {"hits": [], "proj": proj(60, 0.2, "#e8ffd0"), "next": {"light": "L3"}, "gain": 5, "lunge": 0.0}),
		"L3": m("Refulgent Arrow", "shoot_bow", 0.55, 1.9, {"hits": [], "proj": proj(70, 0.3, "#fff0a0"), "gain": 10, "lunge": 0.0}),
		"H": m("Apex Arrow", "shoot_bow_charge", 0.6, 2.4, {"hits": [], "proj": proj(80, 0.45, "#a0ffb0", {"pierce": true}), "charge": 1.5, "lunge": 0.0}),
		"H2": m("Quick Nock", "shoot_bow", 0.5, 0.9, {"hits": [], "proj": proj(55, 0.25, "#e8ffd0", {"spread": 3}), "lunge": 0.0}),
		"S": m("Rain of Death", "shoot_up", 0.7, 1.4, {"hits": [], "rain": 5.0, "stam": 20.0, "lunge": 0.0}),
	}, "actions": [
		act("Wanderer's Minuet", "buff", 60, {"buff": "crit", "amount": 0.3, "time": 25, "party": true}),
		act("Repelling Shot", "backstep", 15, {"dist": 8.0}),
		act("Venomous Bite", "proj", 10, {"pot": 0.8, "color": "#a0ff40", "dot": 0.4}),
		act("Bloodletter", "proj", 6, {"pot": 1.6, "color": "#ff6060"}),
	]}


static func _mch() -> Dictionary:
	return {"moves": {
		"L1": m("Split Shot", "shoot_gun", 0.36, 1.0, {"hits": [], "proj": proj(80, 0.18, "#ffe0a0"), "next": {"light": "L2"}, "gain": 5, "lunge": 0.0}),
		"L2": m("Slug Shot", "shoot_gun", 0.36, 1.15, {"hits": [], "proj": proj(80, 0.18, "#ffe0a0"), "next": {"light": "L3"}, "gain": 5, "lunge": 0.0}),
		"L3": m("Clean Shot", "shoot_gun", 0.5, 1.9, {"hits": [], "proj": proj(90, 0.25, "#fff0c0"), "gain": 10, "lunge": 0.0}),
		"H": m("Drill", "shoot_gun_heavy", 0.7, 2.8, {"hits": [], "proj": proj(70, 0.35, "#ffa060", {"pierce": true}), "lunge": 0.0, "shake": 0.4}),
		"H2": m("Scattergun", "shoot_gun", 0.6, 0.9, {"hits": [], "proj": proj(60, 0.25, "#ffc080", {"spread": 5}), "lunge": 0.0}),
		"S": m("Heat Blast", "shoot_gun", 0.25, 1.5, {"hits": [], "proj": proj(100, 0.2, "#ff8040"), "cost": 10, "alt": "L1", "lunge": 0.0}),
	}, "actions": [
		act("Wildfire", "buff", 90, {"buff": "dmg", "amount": 0.25, "time": 10}),
		act("Air Anchor", "proj", 25, {"pot": 3.0, "color": "#80c0ff", "aoe": 3.0}),
		act("Flamethrower", "beam", 40, {"pot": 2.0, "length": 8.0, "color": "#ff7030"}),
		act("Hypercharge", "gauge", 30, {"amount": 50}),
	]}


static func _dnc() -> Dictionary:
	return {"moves": {
		"L1": m("Cascade", "throw", 0.4, 1.0, {"hits": [], "proj": proj(42, 0.35, "#ff90c0", {"return": true}), "next": {"light": "L2"}, "gain": 10, "lunge": 0.0}),
		"L2": m("Fountain", "throw_l", 0.42, 1.2, {"hits": [], "proj": proj(42, 0.35, "#90e0ff", {"return": true}), "next": {"light": "L3"}, "gain": 10, "lunge": 0.0}),
		"L3": m("Reverse Cascade", "spin", 0.55, 1.5, {"hits": [[0.15, 0.45, 1.5, 3.0, 360.0]], "gain": 10}),
		"H": m("Windmill", "spin", 0.55, 1.1, {"aoe": 3.5, "hits": [[0.15, 0.45, 1.1, 3.5, 360.0]], "next": {"heavy": "H3"}}),
		"H3": m("Bloodshower", "spin", 0.6, 1.6, {"aoe": 4.0, "hits": [[0.15, 0.5, 1.6, 4.0, 360.0]]}),
		"H2": m("Saber Dance", "dance", 0.8, 2.6, {"cost": 50, "alt": "H", "aoe": 4.0, "hits": [[0.4, 0.6, 2.6, 4.0, 360.0]], "nova": "#ffb0e0"}),
		"S": m("Standard Step", "dance", 1.2, 3.2, {"aoe": 5.0, "hits": [[0.9, 1.05, 3.2, 5.0, 360.0]], "buff": "dmg", "buff_amount": 0.1, "buff_time": 20, "nova": "#ffe090", "stam": 20.0}),
	}, "actions": [
		act("En Avant", "dash", 6, {"pot": 0.0, "dist": 9.0}),
		act("Fan Dance", "proj", 4, {"pot": 1.5, "color": "#ff90c0"}),
		act("Curing Waltz", "heal", 30, {"amount": 0.25, "party": true}),
		act("Devilment", "buff", 120, {"buff": "crit", "amount": 0.4, "time": 20}),
	]}


# ----------------------------------------------------------------- CASTERS
static func _blm() -> Dictionary:
	return {"moves": {
		"L1": m("Fire", "cast", 0.6, 1.4, {"hits": [], "proj": proj(30, 0.45, "#ff7a30"), "mp": 600, "next": {"light": "L2"}, "gain": 25, "elem": "fire"}),
		"L2": m("Fire III", "cast_l", 0.75, 1.9, {"hits": [], "proj": proj(30, 0.6, "#ff5020", {"aoe": 2.0}), "mp": 800, "next": {"light": "L3"}, "gain": 25, "elem": "fire"}),
		"L3": m("Fire IV", "cast_up", 1.1, 3.2, {"hits": [], "proj": proj(26, 0.8, "#ff3010", {"aoe": 3.0}), "mp": 1200, "cost": 50, "alt": "L1", "elem": "fire", "shake": 0.5}),
		"H": m("Blizzard III", "cast", 0.8, 1.2, {"hits": [], "proj": proj(34, 0.5, "#a0e0ff", {"aoe": 2.5, "slow": 0.4}), "mp": -3000, "gain": -100, "elem": "ice"}),
		"H2": m("Flare", "cast_up", 1.3, 2.6, {"hits": [], "proj": proj(22, 0.9, "#ff9030", {"aoe": 5.0}), "mp": 2000, "elem": "fire"}),
		"S": m("Thunder III", "cast_up", 0.7, 0.8, {"hits": [], "proj": proj(60, 0.3, "#d0a0ff", {"dot": 0.6, "homing": 8.0}), "mp": 400, "elem": "lightning"}),
	}, "actions": [
		act("Ley Lines", "zone_buff", 90, {"buff": "haste", "amount": 0.25, "radius": 4.0, "time": 20, "color": "#d070ff"}),
		act("Manafont", "mp", 120, {"amount": 6000}),
		act("Aetherial Manipulation", "dash", 10, {"pot": 0.0, "dist": 10.0}),
		act("Xenoglossy", "proj", 30, {"pot": 3.0, "color": "#9060ff"}),
	]}


static func _smn() -> Dictionary:
	return {"moves": {
		"L1": m("Ruin III", "cast", 0.55, 1.2, {"hits": [], "proj": proj(32, 0.4, "#60c0ff"), "next": {"light": "L2"}, "gain": 10}),
		"L2": m("Ruby Rite", "cast_l", 0.6, 1.6, {"hits": [], "proj": proj(30, 0.5, "#ff6040", {"aoe": 2.0}), "next": {"light": "L3"}, "gain": 10, "elem": "fire"}),
		"L3": m("Topaz Rite", "cast_up", 0.65, 1.9, {"hits": [], "proj": proj(36, 0.5, "#e0c060", {"aoe": 2.5}), "gain": 15}),
		"H": m("Emerald Rite", "cast", 0.35, 0.8, {"hits": [], "proj": proj(50, 0.3, "#60ff90"), "gain": 5}),
		"H2": m("Tri-disaster", "cast_up", 0.8, 1.5, {"hits": [], "proj": proj(30, 0.6, "#80a0ff", {"aoe": 4.0}), "mp": 600}),
		"S": m("Summon Bahamut: Megaflare", "summon", 1.4, 4.0, {"hits": [], "aoe": 7.0, "cost": 100, "alt": "S2", "nova": "#80b0ff", "shake": 0.9, "hits_delay": 1.0}),
		"S2": m("Ruin IV", "cast_up", 0.7, 1.8, {"hits": [], "proj": proj(36, 0.6, "#4080ff", {"aoe": 2.5}), "mp": 800, "gain": 20}),
	}, "actions": [
		act("Searing Light", "buff", 120, {"buff": "dmg", "amount": 0.2, "time": 20, "party": true}),
		act("Energy Drain", "proj", 30, {"pot": 1.6, "color": "#60c0ff", "gauge": 25}),
		act("Crimson Cyclone", "dash", 15, {"pot": 1.8, "dist": 10.0}),
		act("Radiant Aegis", "shield", 60, {"amount": 0.2}),
	]}


static func _rdm() -> Dictionary:
	return {"moves": {
		"L1": m("Jolt", "cast", 0.5, 1.0, {"hits": [], "proj": proj(36, 0.3, "#ff6080"), "next": {"light": "L2"}, "gain": 8}),
		"L2": m("Verthunder", "cast_l", 0.65, 1.5, {"hits": [], "proj": proj(40, 0.4, "#c080ff"), "next": {"light": "L3"}, "gain": 12, "elem": "lightning"}),
		"L3": m("Veraero", "cast", 0.65, 1.5, {"hits": [], "proj": proj(40, 0.4, "#90ffc0"), "next": {"light": "L2"}, "gain": 12, "elem": "wind"}),
		"H": m("Enchanted Riposte", "thrust", 0.4, 1.6, {"range": 2.8, "arc": 60.0, "next": {"heavy": "H3"}, "lunge": 1.5}),
		"H3": m("Enchanted Zwerchhau", "slash_r", 0.42, 1.8, {"next": {"heavy": "H4"}}),
		"H4": m("Enchanted Redoublement", "slash_down", 0.55, 2.4, {"lunge": 1.0, "next": {"heavy": "H5"}}),
		"H5": m("Verflare", "cast_up", 0.75, 3.4, {"hits": [], "proj": proj(36, 0.8, "#ff5030", {"aoe": 3.5}), "cost": 50, "alt": "H2", "elem": "fire", "shake": 0.5}),
		"H2": m("Moulinet", "spin", 0.5, 1.0, {"hits": [[0.1, 0.4, 1.0, 3.0, 360.0]]}),
		"S": m("Verholy", "cast_up", 0.8, 3.0, {"hits": [], "proj": proj(36, 0.8, "#fff4c0", {"aoe": 3.5}), "cost": 50, "alt": "S2", "elem": "light", "heal": 0.05}),
		"S2": m("Vercure", "heal", 1.0, 0.0, {"heal": 0.2, "mp": 900, "party_heal": true}),
	}, "actions": [
		act("Corps-a-corps", "dash", 12, {"pot": 1.0, "dist": 9.0}),
		act("Displacement", "backstep", 12, {"pot": 1.0, "dist": 7.0}),
		act("Fleche", "proj", 8, {"pot": 2.2, "color": "#ff4060"}),
		act("Embolden", "buff", 120, {"buff": "dmg", "amount": 0.2, "time": 20, "party": true}),
	]}
