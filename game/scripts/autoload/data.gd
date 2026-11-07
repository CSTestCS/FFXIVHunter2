extends Node
## Static game databases, built once at startup.

var jobs: Dictionary
var monsters: Dictionary
var zones: Dictionary
var cutscenes: Dictionary
var races := RaceData.RACES
var clans := RaceData.CLANS


func _ready() -> void:
	jobs = JobData.all()
	monsters = MonsterData.all()
	zones = ZoneData.all()
	cutscenes = StoryData.cutscenes()


func xp_to_next(level: int) -> int:
	return int(300.0 * pow(level, 1.45))


func item_name(id: String) -> String:
	if ItemData.MATERIALS.has(id): return ItemData.MATERIALS[id]["name"]
	if ItemData.CONSUMABLES.has(id): return ItemData.CONSUMABLES[id]["name"]
	return id.capitalize()


func weapon_name(job: String, tier: int) -> String:
	return "%s %s" % [ItemData.WEAPON_TIERS[tier]["name"], ItemData.WEAPON_NAMES[jobs[job]["weapon"]]]


func meal(slot: String, id: String) -> Dictionary:
	for m in ItemData.MEALS[slot]:
		if m["id"] == id: return m
	return {}


## Small monsters native to a field zone, used by "<small>" story targets.
func zone_small(zone: String) -> String:
	var z: Dictionary = zones.get(zone, {})
	if z.has("mobs") and not z["mobs"].is_empty(): return z["mobs"][0][0]
	return "squirrel"


func zone_large(zone: String) -> String:
	var z: Dictionary = zones.get(zone, {})
	if z.has("hunts") and not z["hunts"].is_empty(): return z["hunts"][0]
	return "coeurl"


func zone_level(zone: String) -> int:
	var z: Dictionary = zones.get(zone, {})
	return z.get("lvl", [1, 1])[0]


func city_of_job(job: String) -> String:
	return jobs[job]["city"]


func cast_appearance(id: String) -> Dictionary:
	var c: Dictionary = StoryData.CAST[id]
	var l: Array = c["look"]
	var ap := RaceData.default_appearance(l[0], l[1], l[2])
	ap["hair_style"] = l[3]; ap["hair_color"] = l[4]
	ap["dye_top"] = l[5]; ap["dye_bottom"] = l[5]; ap["eye_color"] = l[7]
	ap["skin"] = clans[l[1]]["skin"][1 if l[1] in ["duskwight", "xaela", "hellsguard"] else 0]
	return ap
