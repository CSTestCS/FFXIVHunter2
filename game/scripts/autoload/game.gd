extends Node
## Global game state: the active save, progression, quests and scene flow.

signal state_changed
signal toast(text: String)
signal level_up(job: String, level: int)
signal quest_updated

const MAX_LEVEL := 90
const WORLD_SCENE := "res://scenes/world.tscn"

var state: Dictionary = {}
var slot := -1
var pending_spawn: Dictionary = {}   # {zone, pos, cutscene, mission}
var mission: Dictionary = {}         # active quest / leve instance
var new_slot := 0


func _process(delta: float) -> void:
	if not state.is_empty() and not get_tree().paused:
		state["playtime"] = float(state.get("playtime", 0.0)) + delta


# ------------------------------------------------------------------ save lifecycle
func new_game(target_slot: int, c: Dictionary) -> void:
	slot = target_slot
	var job: String = c["job"]
	var city := Data.city_of_job(job)
	state = {
		"version": 1, "name": c["name"], "appearance": c["appearance"], "nameday": c.get("nameday", [1, 0]),
		"deity": c.get("deity", 0), "wol": c["wol"], "job": job, "city": city,
		"jobs": {job: {"level": 1, "xp": 0}}, "weapons": {job: {"tier": 0, "materia": []}},
		"armor": {"head": -1, "body": -1, "legs": -1, "feet": -1}, "armor_materia": {"head": [], "body": [], "legs": [], "feet": []},
		"dyes": {"head": "", "body": "", "legs": "", "feet": ""},
		"gil": 0, "inventory": {}, "materia": [], "meal": {}, "flags": {},
		"msq": 0, "quests_done": [], "active_side": "", "party": [], "recruited": [],
		"zone": "", "pos": [0, 0, 0], "attuned": [], "playtime": 0.0, "hp_frac": 0.35,
	}
	var start: Dictionary = ZoneData.STARTS[city]
	pending_spawn = {"zone": start["zone"], "pos": start["pos"], "cutscene": "opening"}
	save_game()
	get_tree().change_scene_to_file(WORLD_SCENE)


func load_game(s: int) -> bool:
	var d := SaveSystem.load_slot(s)
	if d.is_empty(): return false
	slot = s
	state = d
	var p: Array = state.get("pos", [0, 0, 0])
	pending_spawn = {"zone": state.get("zone", "gridania"), "pos": Vector3(p[0], p[1], p[2])}
	get_tree().change_scene_to_file(WORLD_SCENE)
	return true


func save_game(s := -1) -> bool:
	if s >= 0: slot = s
	if slot < 0 or state.is_empty(): return false
	return SaveSystem.save_slot(slot, state)


func to_title() -> void:
	get_tree().paused = false
	mission = {}
	state = {}
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func goto_zone(zone: String, pos: Vector3, extra := {}) -> void:
	pending_spawn = {"zone": zone, "pos": pos}
	for k in extra: pending_spawn[k] = extra[k]
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_SCENE)


# ------------------------------------------------------------------ helpers
func flag(f: String) -> bool:
	return bool(state.get("flags", {}).get(f, false))


func set_flag(f: String, val := true) -> void:
	state["flags"][f] = val
	state_changed.emit()


func job() -> String:
	return state.get("job", "PLD")


func level(j := "") -> int:
	if j == "": j = job()
	return int(state["jobs"].get(j, {}).get("level", 1))


func city() -> String:
	return state.get("city", "gridania")


func fmt(s: String) -> String:
	var c := city()
	var g: Dictionary = StoryData.GUILDS[c]
	var field: String = g["field"]
	return s.replace("<cityname>", Data.zones[c]["name"]).replace("<guild>", g["guild"]).replace("<inn>", g["inn"]) \
		.replace("<gmname>", StoryData.CAST[g["gm"]]["name"]).replace("<player>", state.get("name", "Adventurer")) \
		.replace("<field>", field)


func resolve_quest(q: Dictionary) -> Dictionary:
	var r := q.duplicate(true)
	var g: Dictionary = StoryData.GUILDS[city()]
	if r.get("zone", "") == "<field>": r["zone"] = g["field"]
	if r.get("talk", "") == "<gm>": r["talk"] = g["gm"]
	if r.get("boss", "") == "<large>": r["boss"] = Data.zone_large(r["zone"])
	if r.has("targets"):
		var t := {}
		for k in r["targets"]:
			t[Data.zone_small(r["zone"]) if k == "<small>" else k] = r["targets"][k]
		r["targets"] = t
	r["desc"] = fmt(r.get("desc", ""))
	return r


# ------------------------------------------------------------------ economy & items
func add_gil(n: int) -> void:
	state["gil"] = max(0, int(state["gil"]) + n)
	state_changed.emit()


func add_item(id: String, n := 1) -> void:
	var inv: Dictionary = state["inventory"]
	inv[id] = int(inv.get(id, 0)) + n
	if inv[id] <= 0: inv.erase(id)
	state_changed.emit()


func count(id: String) -> int:
	return int(state["inventory"].get(id, 0))


func has_mats(mats: Dictionary) -> bool:
	for k in mats:
		if count(k) < int(mats[k]): return false
	return true


func spend_mats(mats: Dictionary) -> void:
	for k in mats: add_item(k, -int(mats[k]))


func add_xp(amount: int) -> void:
	var j := job()
	var e: Dictionary = state["jobs"][j]
	if int(e["level"]) >= MAX_LEVEL: return
	e["xp"] = int(e["xp"]) + amount
	while int(e["level"]) < MAX_LEVEL and int(e["xp"]) >= Data.xp_to_next(int(e["level"])):
		e["xp"] = int(e["xp"]) - Data.xp_to_next(int(e["level"]))
		e["level"] = int(e["level"]) + 1
		level_up.emit(j, int(e["level"]))
		toast.emit("%s has reached level %d!" % [Data.jobs[j]["name"], int(e["level"])])
	state_changed.emit()


func grant(reward: Dictionary) -> String:
	var lines := []
	if reward.get("gil", 0) > 0:
		add_gil(int(reward["gil"])); lines.append("%d gil" % int(reward["gil"]))
	if reward.get("xp", 0) > 0:
		add_xp(int(reward["xp"])); lines.append("%d EXP" % int(reward["xp"]))
	for k in reward.get("items", {}):
		add_item(k, int(reward["items"][k])); lines.append("%s x%d" % [Data.item_name(k), int(reward["items"][k])])
	if reward.has("flag"): set_flag(reward["flag"])
	return ", ".join(lines)


func switch_job(j: String) -> void:
	if not state["jobs"].has(j): return
	state["job"] = j
	if not state["weapons"].has(j): state["weapons"][j] = {"tier": 0, "materia": []}
	state_changed.emit()


func unlock_job_cost() -> int:
	return 800 * state["jobs"].size()


func unlock_job(j: String) -> bool:
	var cost := unlock_job_cost()
	if state["jobs"].has(j) or int(state["gil"]) < cost: return false
	add_gil(-cost)
	state["jobs"][j] = {"level": max(1, level() - 5), "xp": 0}
	state["weapons"][j] = {"tier": 0, "materia": []}
	toast.emit("You may now practice the ways of the %s." % Data.jobs[j]["name"])
	return true


# ------------------------------------------------------------------ stats
func stats() -> Dictionary:
	var j := job()
	var jd: Dictionary = Data.jobs[j]
	var lv := level()
	var w: Dictionary = state["weapons"].get(j, {"tier": 0, "materia": []})
	var tier: Dictionary = ItemData.WEAPON_TIERS[int(w["tier"])]
	var s := {"hp": (600.0 + lv * 110.0) * float(jd["hp_mult"]), "mp": 10000.0, "stam": 100.0, "atk": 22.0 + lv * 6.0 + float(tier["atk"]) * 2.2,
		"def": 0.0, "crit": 0.05, "dmg": 0.0, "haste": 0.0, "stam_regen": 0.0, "mp_regen": 0.0, "regen": 0.0, "swim": 0.0,
		"stagger_res": 0.0, "res_fire": 0.0, "res_ice": 0.0, "res_all": 0.0}
	var mats: Array = []
	mats.append_array(w.get("materia", []))
	for slot_id in state["armor"]:
		var t := int(state["armor"][slot_id])
		if t >= 0: s["def"] += float(ItemData.ARMOR_SETS[t]["def"])
		mats.append_array(state["armor_materia"].get(slot_id, []))
	for mt in mats:
		var md: Dictionary = ItemData.MATERIA[mt["type"]]
		var amt: float = md["per"] * (int(mt["grade"]) + 1)
		match md["stat"]:
			"hp": s["hp"] *= 1.0 + amt
			"mp": s["mp_regen"] += amt * 2.0
			"stam": s["stam"] *= 1.0 + amt
			_: s[md["stat"]] += amt
	for slot_id in state.get("meal", {}):
		var m := Data.meal(slot_id, state["meal"][slot_id])
		for k in m.get("fx", {}):
			match k:
				"hp", "stam":
					s[k] *= 1.0 + float(m["fx"][k])
				"mp":
					s["mp"] *= 1.0 + float(m["fx"][k])
				_:
					s[k] = float(s.get(k, 0.0)) + float(m["fx"][k])
	return s


func materia_slots_weapon() -> int:
	return int(ItemData.WEAPON_TIERS[int(state["weapons"][job()]["tier"])]["slots"])


# ------------------------------------------------------------------ quests
func msq_index() -> int:
	return int(state.get("msq", 0))


func current_msq() -> Dictionary:
	var i := msq_index()
	if i >= StoryData.MAIN.size(): return {}
	return resolve_quest(StoryData.MAIN[i])


func complete_msq() -> String:
	var q := current_msq()
	if q.is_empty(): return ""
	state["msq"] = msq_index() + 1
	state["quests_done"].append(q["id"])
	var r := grant(q.get("reward", {}))
	quest_updated.emit()
	return r


## Builds a randomised guildleve for the player's level around their home region.
func make_leves() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(state.get("playtime", 0.0)).substr(0, 4) + city())
	var lv := level()
	var zones := []
	for z in Data.zones:
		var zd: Dictionary = Data.zones[z]
		if zd["type"] == "field" and int(zd["lvl"][0]) <= lv + 3: zones.append(z)
	if zones.is_empty(): zones.append(StoryData.GUILDS[city()]["field"])
	var out := []
	for t in StoryData.LEVES:
		var z: String = zones[rng.randi() % zones.size()]
		var lq: Dictionary = t.duplicate(true)
		lq["id"] = "leve_%s_%s" % [t["kind"], z]
		lq["zone"] = z
		lq["leve"] = true
		lq["lvl"] = Data.zone_level(z)
		var scale := 1.0 + Data.zone_level(z) * 0.15
		lq["reward"] = {"gil": int(t["gil"] * scale), "xp": int(t["xp"] * scale), "items": {}}
		match t["kind"]:
			"hunt":
				var mob: String = Data.zones[z]["mobs"][rng.randi() % Data.zones[z]["mobs"].size()][0]
				lq["targets"] = {mob: t["count"]}
				lq["desc"] = "Cull %d %s in %s." % [t["count"], Data.monsters[mob]["name"], Data.zones[z]["name"]]
				for d in Data.monsters[mob]["drops"]: lq["reward"]["items"][d] = 2
			"large_hunt":
				lq["boss"] = Data.zones[z]["hunts"][rng.randi() % Data.zones[z]["hunts"].size()]
				lq["name"] = "Mark: " + Data.monsters[lq["boss"]]["name"]
				lq["desc"] = "A bounty has been posted for the %s roaming %s." % [Data.monsters[lq["boss"]]["name"], Data.zones[z]["name"]]
				lq["lvl"] = int(Data.monsters[lq["boss"]]["lvl"])
			"gather":
				lq["desc"] = "Recover %d supply crates scattered across %s." % [t["count"], Data.zones[z]["name"]]
				lq["reward"]["items"] = {"iron_ore": 2, "fire_shard": 3}
			"defense":
				lq["desc"] = "Defend a camp in %s from waves of hostile beasts." % Data.zones[z]["name"]
			"escort":
				lq["desc"] = "Escort a traveling merchant safely across %s." % Data.zones[z]["name"]
		out.append(lq)
	return out


## Starts a quest or leve: travel to its zone with the objective set up (Monster Hunter style "depart").
func depart(q: Dictionary) -> void:
	mission = q.duplicate(true)
	mission["progress"] = {}
	mission["meal"] = state.get("meal", {}).duplicate()
	var z: String = q["zone"]
	var pos := Vector3(0, 0, 90)
	goto_zone(z, pos, {"mission": true, "cutscene": q.get("intro", "")})


func finish_mission(success: bool) -> String:
	var q := mission
	mission = {}
	state["meal"] = {}   # meals last one outing
	if not success: return ""
	if q.get("leve", false):
		return grant(q["reward"])
	for m in StoryData.MAIN:
		if m["id"] == q["id"]: return complete_msq()
	state["quests_done"].append(q["id"])
	quest_updated.emit()
	return grant(q.get("reward", {}))
