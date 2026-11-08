class_name CharModel
extends Node3D
## Assembles a character from the split VRoid parts.
## Clothing stays skinned to the body skeleton. Hair, ears, tails and hats follow a single bone,
## so they are attached rigidly (no per-frame GPU skinning) which keeps crowds cheap.

const DIR := "res://assets/characters/"
const MAT_CACHE_MAX := 512
static var _mat_cache := {}

var appearance: Dictionary = {}
var body: Node3D
var skel: Skeleton3D
var anim: AnimationPlayer
var face: MeshInstance3D
var weapon_r: Node3D
var weapon_l: Node3D
var _hand_r: BoneAttachment3D
var _hand_l: BoneAttachment3D
var _back: BoneAttachment3D
var _tail_pivot: Node3D
var _blink_t := 2.0
var _blink := 0.0
var talking := false
var _talk_t := 0.0
var _morph := {}          # VRoid blend shape name -> index
var _expr := "neutral"
var _expr_w := {}         # expression -> current weight (blended smoothly)
var _vis := {}            # viseme vowel -> current weight
var _vis_target := ""
var _vis_t := 0.0

const EXPRESSIONS := {"angry": "Fcl_ALL_Angry", "fun": "Fcl_ALL_Fun", "joy": "Fcl_ALL_Joy", "sorrow": "Fcl_ALL_Sorrow", "surprised": "Fcl_ALL_Surprised"}
const VISEMES := {"a": "Fcl_MTH_A", "i": "Fcl_MTH_I", "u": "Fcl_MTH_U", "e": "Fcl_MTH_E", "o": "Fcl_MTH_O"}
var current_anim := ""
var weapon_type := ""
var drawn := false
var far := false


func build(ap: Dictionary, gear := {}) -> void:
	appearance = ap.duplicate()
	for c in get_children(): c.queue_free()
	var race: String = ap.get("race", "hyur")
	var sex: String = ap.get("sex", "f")
	var rd: Dictionary = RaceData.RACES[race]
	var base: String = rd["base"]
	var key := "%s_%s" % [base, sex]
	body = load(DIR + "base_%s.gltf" % key).instantiate()
	body.name = "Body"
	body.rotation.y = PI   # VRoid faces +Z; Godot forward is -Z.
	add_child(body)
	skel = body.get_node("Skeleton3D")
	for mi in skel.get_children():
		if mi is MeshInstance3D:
			if mi.name == "Face":
				face = mi
				for i in mi.mesh.get_blend_shape_count():
					_morph[str(mi.mesh.get_blend_shape_name(i))] = i
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# --- hair
	var style: int = int(ap.get("hair_style", 1))
	var hs: Dictionary = RaceData.HAIRSTYLES[clampi(style, 0, RaceData.HAIRSTYLES.size() - 1)]
	if hs["part"] == "":
		_attach_rigid("hairback_%s" % sex, "J_Bip_C_Head")
	else:
		_attach_rigid(hs["part"], "J_Bip_C_Head")
	# --- racial features
	match rd["ears"]:
		"cat":
			_attach_rigid("ears_miqote_%s" % sex, "J_Bip_C_Head", Vector3(1, 0.85 + float(ap.get("ear_size", 0.5)) * 0.4, 1))
		"rabbit":
			_attach_rigid("ears_miqote_%s" % sex, "J_Bip_C_Head", Vector3(0.75, 2.2 + float(ap.get("ear_size", 0.5)) * 0.8, 0.8), Vector3(0, 0.14, 0))
		"long":
			_add_pointed_ears(0.09 + float(ap.get("ear_size", 0.5)) * 0.05)
		"small":
			_add_pointed_ears(0.05)
	if rd["horns"]: _add_horns(float(ap.get("ear_size", 0.5)))
	match rd["tail"]:
		"cat": _attach_tail("tail_miqote_%s" % sex, 0.6 + float(ap.get("tail_length", 0.5)) * 0.8)
		"scaled": _add_scaled_tail(0.6 + float(ap.get("tail_length", 0.5)) * 0.8)
	# --- clothing (skinned to the body)
	var armor: Dictionary = gear.get("armor", {})
	var dyes: Dictionary = gear.get("dyes", {})
	var file_base := "%s_%s" % [base, sex]
	for slot in [["body", "tops"], ["legs", "bottoms"], ["feet", "shoes"]]:
		var tier := int(armor.get(slot[0], -1))
		if tier >= 0:
			_attach_skinned("%s_%s" % [file_base, slot[1]], _armor_look(tier, dyes.get(slot[0], "")))
	var head_tier := int(armor.get("head", -1))
	if head_tier >= 0:
		_attach_rigid("%s_cap" % file_base, "J_Bip_C_Head", Vector3.ONE, Vector3.ZERO, _armor_look(head_tier, dyes.get("head", "")))
	_apply_body_shape(ap)
	_apply_colors(ap)
	# --- animation
	anim = AnimationPlayer.new()
	anim.name = "Anim"
	body.add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library("", AnimLib.library_for(skel, key))
	play("idle", 0.0)
	# --- weapon sockets
	_hand_r = _socket("J_Bip_R_Hand")
	_hand_l = _socket("J_Bip_L_Hand")
	_back = _socket("J_Bip_C_UpperChest")
	if gear.has("weapon"): set_weapon(gear["weapon"], int(gear.get("tier", 0)))
	if not Settings.changed.is_connected(_place_weapons): Settings.changed.connect(_place_weapons)


func _socket(bone: String) -> BoneAttachment3D:
	var b := BoneAttachment3D.new()
	b.bone_name = bone
	skel.add_child(b)
	return b


func _load_part(part: String) -> Node3D:
	var path := DIR + part + ".gltf"
	if not ResourceLoader.exists(path): return null
	return load(path).instantiate()


func _attach_skinned(part: String, look := {}) -> void:
	var inst := _load_part(part)
	if inst == null: return
	var src: Skeleton3D = inst.get_node("Skeleton3D")
	for mi in src.get_children():
		if mi is MeshInstance3D:
			mi.owner = null
			src.remove_child(mi)
			skel.add_child(mi)
			mi.skeleton = NodePath("..")
			if not look.is_empty(): _tint_mesh(mi, look)
	inst.free()


## Converts a part that follows one bone into a static mesh parented to that bone.
func _attach_rigid(part: String, bone: String, scl := Vector3.ONE, pivot := Vector3.ZERO, look := {}) -> Node3D:
	var inst := _load_part(part)
	if inst == null: return null
	var src: Skeleton3D = inst.get_node("Skeleton3D")
	var bi := src.find_bone(bone)
	var src_rest := src.get_bone_global_rest(bi)
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	skel.add_child(att)
	var holder := Node3D.new()
	att.add_child(holder)
	# Scale around a pivot in bone space (e.g. the crown of the head for ears).
	holder.transform = Transform3D(Basis.from_scale(scl), pivot - Basis.from_scale(scl) * pivot)
	for mi in src.get_children():
		if mi is MeshInstance3D:
			mi.owner = null
			src.remove_child(mi)
			holder.add_child(mi)
			mi.skin = null
			mi.skeleton = NodePath("")
			mi.transform = src_rest.affine_inverse()
			if not look.is_empty(): _tint_mesh(mi, look)
	inst.free()
	return holder


func _attach_tail(part: String, length: float) -> void:
	var inst := _load_part(part)
	if inst == null: return
	var src: Skeleton3D = inst.get_node("Skeleton3D")
	var hips_rest := src.get_bone_global_rest(src.find_bone("J_Bip_C_Hips"))
	inst.free()
	# Pivot at the base of the tail (just behind the hips) so it can sway.
	var att := BoneAttachment3D.new(); att.bone_name = "J_Bip_C_Hips"; skel.add_child(att)
	_tail_pivot = Node3D.new(); att.add_child(_tail_pivot)
	var base := Vector3(0, -0.05, -0.08)
	_tail_pivot.position = base
	var holder := _attach_rigid(part, "J_Bip_C_Hips")
	if holder == null: return
	var att2 := holder.get_parent()
	holder.reparent(_tail_pivot, false)
	att2.queue_free()
	holder.transform = Transform3D(Basis.from_scale(Vector3(1, 1, length)), -base * Vector3(1, 1, length))
	for mi in holder.get_children(): mi.transform = hips_rest.affine_inverse()


func _skin_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(appearance.get("skin", "#f0d0b8"))
	m.roughness = 0.6
	return m


func _add_pointed_ears(len: float) -> void:
	var att := BoneAttachment3D.new(); att.bone_name = "J_Bip_C_Head"; skel.add_child(att)
	var mat := _skin_mat()
	for s in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		var pm := PrismMesh.new(); pm.size = Vector3(0.035, len, 0.012)
		mi.mesh = pm; mi.material_override = mat
		mi.position = Vector3(0.072 * s, 0.065, -0.012)
		mi.rotation = Vector3(deg_to_rad(-55), 0, deg_to_rad(-62 * s))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		att.add_child(mi)


func _add_horns(size: float) -> void:
	var att := BoneAttachment3D.new(); att.bone_name = "J_Bip_C_Head"; skel.add_child(att)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(appearance.get("feature_color", "#2a2a2a")).darkened(0.2)
	mat.roughness = 0.35; mat.metallic_specular = 0.7
	for s in [-1.0, 1.0]:
		var prev: Node3D = att
		var root := Node3D.new(); root.position = Vector3(0.06 * s, 0.1, 0.03)
		root.rotation = Vector3(deg_to_rad(-60), deg_to_rad(15 * s), deg_to_rad(-20 * s))
		att.add_child(root); prev = root
		var seg_len := 0.045 + size * 0.03
		for i in 3:
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new(); cm.top_radius = 0.016 * (1.0 - (i + 1) / 3.5); cm.bottom_radius = 0.018 * (1.0 - i / 3.5)
			cm.height = seg_len; cm.radial_segments = 8; cm.rings = 1
			mi.mesh = cm; mi.material_override = mat; mi.position = Vector3(0, seg_len * 0.5, 0)
			prev.add_child(mi)
			var nxt := Node3D.new(); nxt.position = Vector3(0, seg_len, 0); nxt.rotation.x = deg_to_rad(-22)
			prev.add_child(nxt); prev = nxt


func _add_scaled_tail(length: float) -> void:
	var att := BoneAttachment3D.new(); att.bone_name = "J_Bip_C_Hips"; skel.add_child(att)
	_tail_pivot = Node3D.new(); _tail_pivot.position = Vector3(0, -0.04, -0.09); att.add_child(_tail_pivot)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(appearance.get("skin", "#e0d0c0")).lerp(Color(appearance.get("feature_color", "#303030")), 0.5)
	mat.roughness = 0.4
	var prev: Node3D = _tail_pivot
	prev.rotation.x = deg_to_rad(-120)
	var seg := 0.16 * length
	for i in 4:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.bottom_radius = 0.05 * (1.0 - i * 0.22); cm.top_radius = 0.05 * (1.0 - (i + 1) * 0.22)
		cm.height = seg; cm.radial_segments = 8; cm.rings = 1
		mi.mesh = cm; mi.material_override = mat; mi.position.y = seg * 0.5
		prev.add_child(mi)
		var nxt := Node3D.new(); nxt.position.y = seg; nxt.rotation.x = deg_to_rad(14); prev.add_child(nxt); prev = nxt


func _bone_scale(bone: String, s: Vector3) -> void:
	var i := skel.find_bone(bone)
	if i >= 0: skel.set_bone_pose_scale(i, s)


func _apply_body_shape(ap: Dictionary) -> void:
	var race: String = ap.get("race", "hyur")
	var clan: Dictionary = RaceData.CLANS[ap.get("clan", "midlander")]
	var h: float = clan["scale"] * RaceData.SEX_SCALE.get("%s_%s" % [race, ap.get("sex", "f")], 1.0)
	h *= 0.94 + float(ap.get("height", 0.5)) * 0.12
	scale = Vector3.ONE * h
	var w: float = clan["width"] * (0.96 + float(ap.get("muscle", 0.5)) * 0.1)
	# Widen the torso; counter-scale the shoulders and neck so arms and head keep their proportions.
	_bone_scale("J_Bip_C_Spine", Vector3(w, 1, w))
	for b in ["J_Bip_L_Shoulder", "J_Bip_R_Shoulder", "J_Bip_C_Neck"]:
		_bone_scale(b, Vector3(1.0 / w, 1, 1.0 / w))
	var leg: float = 0.97 + (w - 1.0) * 0.8
	for b in ["J_Bip_L_UpperLeg", "J_Bip_R_UpperLeg"]:
		_bone_scale(b, Vector3(leg, 1, leg))
	var m: float = 0.92 + float(ap.get("muscle", 0.5)) * 0.18
	for b in ["J_Bip_L_UpperArm", "J_Bip_R_UpperArm"]:
		_bone_scale(b, Vector3(1, m, m))
	_bone_scale("J_Bip_C_Head", Vector3.ONE * float(clan["head"]))
	if ap.get("sex", "f") == "f":
		var b: float = 0.75 + float(ap.get("bust", 0.5)) * 0.55
		_bone_scale("J_Sec_L_Bust1", Vector3.ONE * b)
		_bone_scale("J_Sec_R_Bust1", Vector3.ONE * b)


func _armor_look(tier: int, dye: String) -> Dictionary:
	var s: Dictionary = ItemData.ARMOR_SETS[clampi(tier, 0, ItemData.ARMOR_SETS.size() - 1)]
	return {"color": dye if dye != "" else s["color"], "metal": s["metal"], "rough": s["rough"]}


func _tint_mesh(mi: MeshInstance3D, look: Dictionary) -> void:
	for i in mi.mesh.get_surface_count():
		var src: Material = mi.mesh.surface_get_material(i)
		var key := "cloth|%s|%s|%s|%s" % [src.get_rid().get_id(), look["color"], look["metal"], look["rough"]]
		mi.set_surface_override_material(i, _cached(key, src, func(m: StandardMaterial3D):
			m.albedo_color = Color(look["color"])
			m.metallic = look["metal"]
			m.roughness = look["rough"]))


func _cached(key: String, src: Material, setup: Callable) -> Material:
	if _mat_cache.has(key): return _mat_cache[key]
	if _mat_cache.size() > MAT_CACHE_MAX: _mat_cache.clear()
	var m: StandardMaterial3D = src.duplicate()
	setup.call(m)
	_mat_cache[key] = m
	return m


func _apply_colors(ap: Dictionary) -> void:
	var skin := Color(ap.get("skin", "#f0d0b8"))
	var hair := Color(ap.get("hair_color", "#3b2a20"))
	var hl := Color(ap.get("highlight_color", "#c9a26b"))
	var eye := Color(ap.get("eye_color", "#2d5b8a"))
	var sss: bool = Settings.gfx.get("sss", false)
	var tinted: bool = ap.get("tint", "") != ""
	for mi in _all_meshes(self):
		if mi.material_override != null: continue
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			if src == null or mi.get_surface_override_material(i) != null: continue
			var n: String = src.resource_name
			var key := ""
			var setup: Callable
			if "_SKIN" in n:
				var col := skin if not tinted else skin.lerp(Color(ap["tint"]), 0.6)
				key = "skin|%s|%s|%s" % [src.get_rid().get_id(), col.to_html(), sss]
				setup = func(m: StandardMaterial3D):
					m.albedo_color = col
					m.roughness = 0.55
					if sss:
						m.subsurf_scatter_enabled = true; m.subsurf_scatter_strength = 0.18; m.subsurf_scatter_skin_mode = true
			elif "_HAIR" in n or "CatEar" in n or "FoxTail" in n:
				var col := hair
				if ap.get("highlights", false) and not "HairBack" in n: col = hair.lerp(hl, 0.35)
				key = "hair|%s|%s" % [src.get_rid().get_id(), col.to_html()]
				setup = func(m: StandardMaterial3D):
					m.albedo_color = col
					m.cull_mode = BaseMaterial3D.CULL_DISABLED
					m.roughness = 0.45
					m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
			elif "FaceEyeline" in n or "FaceMouth" in n:
				# Eyelid/eyeline and mouth layers carry painted skin, so they follow the skin tone.
				var col := skin if not tinted else skin.lerp(Color(ap["tint"]), 0.6)
				key = "faceskin|%s|%s" % [src.get_rid().get_id(), col.to_html()]
				setup = func(m: StandardMaterial3D):
					m.albedo_color = col
					m.roughness = 0.55
			elif "EyeIris" in n:
				key = "iris|%s|%s" % [src.get_rid().get_id(), eye.to_html()]
				setup = func(m: StandardMaterial3D):
					m.albedo_color = eye
					m.roughness = 0.1
			elif "Brow" in n:
				key = "brow|%s|%s" % [src.get_rid().get_id(), hair.to_html()]
				setup = func(m: StandardMaterial3D): m.albedo_color = hair.lightened(0.25)
			if key != "":
				mi.set_surface_override_material(i, _cached(key, src, setup))


static func _all_meshes(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is MeshInstance3D: out.append(c)
		out.append_array(_all_meshes(c))
	return out


# ----------------------------------------------------------------------------- weapons
func set_weapon(type: String, tier := 0) -> void:
	weapon_type = type
	if weapon_r: weapon_r.queue_free(); weapon_r = null
	if weapon_l: weapon_l.queue_free(); weapon_l = null
	if type == "": return
	var w := WeaponBuilder.build(type, tier)
	weapon_r = w[0]
	weapon_l = w[1]
	_place_weapons()


func set_drawn(v: bool) -> void:
	if drawn == v and weapon_r and weapon_r.get_parent() != null: return
	drawn = v
	_place_weapons()


func _place_weapons() -> void:
	for w in [weapon_r, weapon_l]:
		if w and w.get_parent(): w.get_parent().remove_child(w)
	if not drawn and Settings.v.get("hide_sheathed", false):
		return  # option: weapons vanish while sheathed and reappear when drawn
	var bow := weapon_type == "bow"
	if weapon_r:
		if drawn:
			(_hand_l if bow else _hand_r).add_child(weapon_r)
			weapon_r.transform = WeaponBuilder.grip(not bow, weapon_type)
		else:
			_back.add_child(weapon_r)
			weapon_r.transform = WeaponBuilder.sheath(weapon_type, 0)
	if weapon_l:
		if drawn:
			_hand_l.add_child(weapon_l)
			weapon_l.transform = WeaponBuilder.grip(false, weapon_type, true)
		else:
			_back.add_child(weapon_l)
			weapon_l.transform = WeaponBuilder.sheath(weapon_type, 1)


## World-space tip of the main weapon (for trails and projectile spawn).
func weapon_tip() -> Vector3:
	if weapon_r and weapon_r.is_inside_tree():
		return weapon_r.global_transform * Vector3(0, float(weapon_r.get_meta("length", 0.8)), 0)
	return global_position + Vector3(0, 1.3, 0)


func hand_pos(right := true) -> Vector3:
	var h := _hand_r if right else _hand_l
	return h.global_position if h and h.is_inside_tree() else global_position + Vector3(0, 1.2, 0)


# ----------------------------------------------------------------------------- animation & face
func play(name: String, blend := 0.15, speed := 1.0) -> void:
	if anim == null or not anim.has_animation(name): return
	if name == current_anim and anim.is_playing() and anim.get_animation(name).loop_mode != Animation.LOOP_NONE:
		anim.speed_scale = speed
		return
	current_anim = name
	anim.play(name, blend)
	anim.speed_scale = speed


func replay(name: String, blend := 0.08, speed := 1.0) -> void:
	current_anim = ""
	play(name, blend, speed)
	anim.seek(0.0, true)


func set_far(v: bool) -> void:
	if far == v: return
	far = v
	if anim: anim.speed_scale = 0.0 if v else 1.0


## Face expression: neutral, angry, fun, joy, sorrow or surprised. Blends in smoothly.
func set_expression(e: String) -> void:
	_expr = e if EXPRESSIONS.has(e) else "neutral"


## Mouth shape for the character currently being spoken (vowels map to VRoid visemes).
func speak_char(ch: String) -> void:
	var c := ch.to_lower()
	if VISEMES.has(c): _vis_target = c
	elif c == "y": _vis_target = "i"
	elif c == "w": _vis_target = "u"
	elif c in [" ", ".", ",", "!", "?", ";", ":", "\n"]: _vis_target = ""
	else: _vis_target = "a" if _vis_target == "" else _vis_target
	_vis_t = 0.12


## Head position in world space (for cameras framing a face).
func head_pos() -> Vector3:
	if skel == null: return global_position + Vector3(0, 1.5, 0)
	var i := skel.find_bone("J_Bip_C_Head")
	if i < 0: return global_position + Vector3(0, 1.5 * scale.y, 0)
	return skel.global_transform * (skel.get_bone_global_pose(i).origin + Vector3(0, 0.07, 0))


func _set_morph(name: String, w: float) -> void:
	if _morph.has(name): face.set_blend_shape_value(_morph[name], w)


func _process(delta: float) -> void:
	if face == null or far: return
	var k := clampf(delta * 8.0, 0.0, 1.0)
	for e in EXPRESSIONS:
		var w: float = lerpf(float(_expr_w.get(e, 0.0)), 1.0 if e == _expr else 0.0, k)
		_expr_w[e] = w
		_set_morph(EXPRESSIONS[e], w)
	# Smiles already close the eyes, so skip blinking while one is showing.
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink = 0.16; _blink_t = randf_range(2.5, 5.5)
	var blink_w := 0.0
	if _blink > 0.0:
		_blink -= delta
		blink_w = sin(clampf(_blink / 0.16, 0.0, 1.0) * PI) * (1.0 - float(_expr_w.get("joy", 0.0)) - float(_expr_w.get("fun", 0.0)))
	_set_morph("Fcl_EYE_Close", maxf(blink_w, 0.0))
	# Visemes: driven by dialogue text when available, otherwise a gentle open/close while talking.
	_vis_t -= delta
	var target := _vis_target if _vis_t > 0.0 else ""
	if talking and _vis_t <= 0.0:
		_talk_t += delta * 9.0
		target = ["a", "o", "e", "a", "i", "u"][int(_talk_t) % 6] if fmod(_talk_t, 1.0) < 0.6 else ""
	for v in VISEMES:
		var w: float = lerpf(float(_vis.get(v, 0.0)), (0.75 if v == "a" else 0.85) if v == target else 0.0, clampf(delta * 18.0, 0.0, 1.0))
		_vis[v] = w
		_set_morph(VISEMES[v], w)
	if _tail_pivot:
		_tail_pivot.rotation.y = sin(Time.get_ticks_msec() * 0.0021) * 0.25
