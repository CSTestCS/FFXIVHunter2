class_name NPC
extends StaticBody3D
## Interactable townsfolk. Their animation pauses and models hide when far from the camera.

var role := "citizen"
var npc_name := ""
var quest_id := ""
var cast_id := ""
var model: CharModel
var label: Label3D
var marker: Label3D
var _wander := Vector3.ZERO
var _home := Vector3.ZERO
var _t := 0.0
var world: Node
var busy := false   # in conversation: stands still facing the player

const LINES := [
	"Have you heard? They say the Warrior of Light was seen near the Crystal Tower.",
	"Another fine day with no moon falling on our heads. I'll take it.",
	"The roads have been dangerous of late. Bandits, they say.",
	"My cousin swears a coeurl the size of a house lives out past the camp.",
	"Eat well before heading out, friend. A full belly is the best armour.",
	"The guild's been busier than ever since the Final Days. Folk need help rebuilding.",
	"I heard the Scions disbanded. Strange times, quiet times.",
]


func setup(d: Dictionary, w: Node) -> void:
	world = w
	role = d.get("role", "citizen")
	quest_id = d.get("quest", "")
	cast_id = d.get("cast", "")
	collision_layer = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.35; cap.height = 1.7
	cs.shape = cap; cs.position.y = 0.85
	add_child(cs)
	model = CharModel.new()
	add_child(model)
	var ap: Dictionary
	if cast_id != "":
		ap = Data.cast_appearance(cast_id)
		npc_name = StoryData.CAST[cast_id]["name"]
	else:
		ap = random_look(hash(str(d["pos"]) + role))
		npc_name = d.get("name", "")
		if npc_name == "": npc_name = ["Citizen", "Traveler", "Merchant", "Local", "Sightseer"][abs(hash(str(d["pos"]))) % 5]
	var outfit := {"body": 0, "legs": 0, "feet": 0}
	if role in ["smith", "guildmaster", "trainer"]: outfit = {"body": 2, "legs": 1, "feet": 1}
	model.build(ap, {"armor": outfit, "dyes": {"body": ap.get("dye_top", ""), "legs": ap.get("dye_bottom", "")}})
	model.set_drawn(false)
	label = Label3D.new()
	label.text = npc_name
	label.font_size = 36
	label.pixel_size = 0.006
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("#e8f4ff") if role != "citizen" else Color("#c8ccd4")
	label.position = Vector3(0, 2.15 * model.scale.y, 0)
	label.visibility_range_end = 18.0
	add_child(label)
	marker = Label3D.new()
	marker.font_size = 72; marker.pixel_size = 0.006; marker.outline_size = 12
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.position = Vector3(0, 2.55 * model.scale.y, 0)
	marker.modulate = Color("#ffd860")
	marker.visibility_range_end = 45.0
	add_child(marker)
	refresh_marker()
	_home = d["pos"]
	_wander = _home
	if role == "citizen": model.play("idle")
	elif role in ["guildmaster", "inn", "market"]: model.play("talk")


static func random_look(seed_v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_v
	var races := RaceData.RACES.keys()
	var r: String = races[rng.randi() % races.size()]
	var clans: Array = RaceData.RACES[r]["clans"]
	var c: String = clans[rng.randi() % clans.size()]
	var ap := RaceData.default_appearance(r, c, "f" if rng.randf() < 0.5 else "m")
	ap["hair_style"] = rng.randi() % 3
	ap["hair_color"] = RaceData.HAIR_COLORS[rng.randi() % RaceData.HAIR_COLORS.size()]
	ap["eye_color"] = RaceData.EYE_COLORS[rng.randi() % RaceData.EYE_COLORS.size()]
	var tones: Array = RaceData.CLANS[c]["skin"]
	ap["skin"] = tones[rng.randi() % tones.size()]
	ap["height"] = rng.randf()
	ap["dye_top"] = ["#8a5a3a", "#3c5a8a", "#6a7a3a", "#a03a3a", "#d8ccb0", "#5a3a6a"][rng.randi() % 6]
	ap["dye_bottom"] = ["#4a3a2a", "#2a2a3a", "#6a5a4a", "#3a4a3a"][rng.randi() % 4]
	return ap


func refresh_marker() -> void:
	var m := ""
	match role:
		"guildmaster":
			var q := Game.current_msq()
			if not q.is_empty() and q.get("talk", "") == cast_id: m = "!"
			elif not q.is_empty() and q["kind"] != "talk": m = "!"
		"side":
			if quest_id != "" and not quest_id in Game.state.get("quests_done", []): m = "!"
		"leves":
			m = "?" if Game.flag("leves") else ""
		"story":
			var q := Game.current_msq()
			if not q.is_empty() and q["kind"] == "talk" and q.get("talk", "") == cast_id: m = "!"
	marker.text = m
	marker.modulate = Color("#ffd860") if m == "!" else Color("#80d0ff")


func prompt() -> String:
	return {"guildmaster": "Talk", "leves": "Guildleves", "recruiter": "Party", "inn": "Order a Meal", "smith": "Upgrade & Meld",
		"market": "Trade", "trainer": "Jobs", "side": "Talk", "ferry": "Board Ferry", "citizen": "Talk"}.get(role, "Talk")


func line() -> String:
	if StoryData.CAST_LINES.has(cast_id):
		var cl: Array = StoryData.CAST_LINES[cast_id]
		return cl[abs(hash(str(Time.get_ticks_msec() / 6000))) % cl.size()]
	return LINES[abs(hash(npc_name + str(Time.get_ticks_msec() / 8000))) % LINES.size()]


func _physics_process(delta: float) -> void:
	if world == null or world.player == null: return
	var dist := global_position.distance_to(world.player.global_position)
	var far := dist > 45.0
	model.set_far(far)
	model.visible = dist < 110.0
	if far or role != "citizen" or busy: return
	_t -= delta
	if _t <= 0.0:
		_t = randf_range(4.0, 9.0)
		_wander = _home + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
	var to := _wander - global_position
	to.y = 0
	if to.length() > 0.4:
		var step := to.normalized() * 1.3 * delta
		global_position += step
		global_position.y = world.ground_height(global_position.x, global_position.z)
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 5.0 * delta)
		model.play("walk")
	else:
		model.play("idle")
