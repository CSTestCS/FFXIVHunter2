class_name AnimLib
## Procedurally authored humanoid animations for the VRoid skeleton (model faces +Z, T-pose rest).
## Poses are written per limb and converted to bone rotations relative to each bone's rest.
## Libraries are generated once per skeleton layout and shared by every character using it.
##
## Pose keys:
##   L / R  : arm  [down, forward, twist, elbow, wrist]   (degrees)
##   LL / RL: leg  [forward, outward, knee, foot]
##   hips, spine, chest, neck, head: [pitch(+ = lean forward), yaw(+ = turn left), roll]
##   hy / hz: hip height / forward offset (metres)

static var _cache := {}

const BONES := {
	"hips": "J_Bip_C_Hips", "spine": "J_Bip_C_Spine", "chest": "J_Bip_C_Chest", "uchest": "J_Bip_C_UpperChest",
	"neck": "J_Bip_C_Neck", "head": "J_Bip_C_Head",
	"lua": "J_Bip_L_UpperArm", "lla": "J_Bip_L_LowerArm", "lh": "J_Bip_L_Hand",
	"rua": "J_Bip_R_UpperArm", "rla": "J_Bip_R_LowerArm", "rh": "J_Bip_R_Hand",
	"lul": "J_Bip_L_UpperLeg", "lll": "J_Bip_L_LowerLeg", "lf": "J_Bip_L_Foot",
	"rul": "J_Bip_R_UpperLeg", "rll": "J_Bip_R_LowerLeg", "rf": "J_Bip_R_Foot",
}

const RELAX := {"L": [76, 6, 0, 12, 0], "R": [76, 6, 0, 12, 0], "LL": [0, 2, 0, 0], "RL": [0, 2, 0, 0]}
const GUARD := {"L": [55, 35, 0, 70, 0], "R": [62, 28, 0, 60, 0], "LL": [12, 6, 24, -10], "RL": [-10, 5, 14, 6], "spine": [6, 10, 0], "hy": -0.06}


static func library_for(skel: Skeleton3D, key: String) -> AnimationLibrary:
	if _cache.has(key): return _cache[key]
	var lib := AnimationLibrary.new()
	var rest := {}
	for alias in BONES:
		var i := skel.find_bone(BONES[alias])
		rest[alias] = skel.get_bone_rest(i) if i >= 0 else Transform3D()
	var defs := _definitions()
	for name in defs:
		var d: Array = defs[name]
		lib.add_animation(name, _build(d[0], d[1], d[2], rest))
	_cache[key] = lib
	return lib


# ----------------------------------------------------------------------------- conversion
static func _q(x: float, y: float, z: float) -> Quaternion:
	return Quaternion.from_euler(Vector3(deg_to_rad(x), deg_to_rad(y), deg_to_rad(z)))


static func _axis(ax: Vector3, deg: float) -> Quaternion:
	return Quaternion(ax, deg_to_rad(deg))


## Converts a pose dictionary into {bone alias: Quaternion delta} and hip offset.
static func _pose_to_rot(p: Dictionary) -> Dictionary:
	var out := {}
	for side in ["L", "R"]:
		var a: Array = p.get(side, RELAX[side])
		var s := 1.0 if side == "L" else -1.0
		var down: float = a[0]; var fwd: float = a[1]; var tw: float = a[2]; var elb: float = a[3]
		var wr: float = a[4] if a.size() > 4 else 0.0
		var ua := _axis(Vector3.UP, -s * fwd) * _axis(Vector3.BACK, -s * down) * _axis(Vector3.RIGHT, s * tw)
		out["lua" if side == "L" else "rua"] = ua
		out["lla" if side == "L" else "rla"] = _axis(Vector3.UP, -s * elb)
		out["lh" if side == "L" else "rh"] = _axis(Vector3.BACK, s * wr)
	for side in ["LL", "RL"]:
		var l: Array = p.get(side, RELAX[side])
		var s := 1.0 if side == "LL" else -1.0
		var pre := "l" if side == "LL" else "r"
		out[pre + "ul"] = _axis(Vector3.BACK, s * l[1]) * _axis(Vector3.RIGHT, -l[0])
		out[pre + "ll"] = _axis(Vector3.RIGHT, l[2])
		out[pre + "f"] = _axis(Vector3.RIGHT, l[3] if l.size() > 3 else 0.0)
	for b in ["hips", "spine", "chest", "neck", "head"]:
		var e: Array = p.get(b, [0, 0, 0])
		out[b] = _q(e[0], e[1], e[2])
	return out


static func _build(length: float, loop: bool, keys: Array, rest: Dictionary) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var tracks := {}
	var aliases := ["hips", "spine", "chest", "neck", "head", "lua", "lla", "lh", "rua", "rla", "rh", "lul", "lll", "lf", "rul", "rll", "rf"]
	for alias in aliases:
		var t := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, NodePath("Skeleton3D:" + BONES[alias]))
		anim.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
		anim.track_set_interpolation_loop_wrap(t, loop)
		tracks[alias] = t
	var pt := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pt, NodePath("Skeleton3D:" + BONES["hips"]))
	anim.track_set_interpolation_type(pt, Animation.INTERPOLATION_CUBIC)
	anim.track_set_interpolation_loop_wrap(pt, loop)
	var hip_rest: Vector3 = rest["hips"].origin
	for k in keys:
		var tm: float = clampf(float(k[0]) * length, 0.0, length)
		var pose: Dictionary = k[1]
		var rots := _pose_to_rot(pose)
		for alias in aliases:
			var rq: Quaternion = rest[alias].basis.get_rotation_quaternion()
			anim.rotation_track_insert_key(tracks[alias], tm, rq * rots[alias])
		anim.position_track_insert_key(pt, tm, hip_rest + Vector3(0, float(pose.get("hy", 0.0)), float(pose.get("hz", 0.0))))
	return anim


static func _m(base: Dictionary, over: Dictionary) -> Dictionary:
	var d := base.duplicate()
	for k in over: d[k] = over[k]
	return d


# ----------------------------------------------------------------------------- definitions
## name: [length, loop, [[t(0..1), pose], ...]]
static func _definitions() -> Dictionary:
	var R := RELAX
	var G := GUARD
	var d := {}
	d["idle"] = [3.2, true, [
		[0.0, _m(R, {"chest": [0, 0, 0]})],
		[0.5, _m(R, {"chest": [-2, 0, 0], "L": [74, 6, 0, 14, 0], "R": [74, 6, 0, 14, 0], "head": [-1, 2, 0]})],
		[1.0, _m(R, {"chest": [0, 0, 0]})]]]
	d["idle_combat"] = [2.0, true, [
		[0.0, G], [0.5, _m(G, {"hy": -0.075, "chest": [8, 10, 0]})], [1.0, G]]]
	d["walk"] = [1.0, true, _cycle(26, 6, 0.03, [76, 22, 0, 18], 0.0)]
	d["run"] = [0.68, true, _cycle(42, 12, 0.06, [72, 38, 0, 85], 10.0)]
	d["sprint"] = [0.52, true, _cycle(55, 16, 0.07, [65, 55, 0, 95], 18.0)]
	d["walk_combat"] = [0.9, true, _cycle(24, 8, 0.03, [58, 30, 0, 65], 6.0, -0.05)]
	d["strafe"] = [0.8, true, [
		[0.0, _m(G, {"LL": [-10, 22, 25, 0], "RL": [5, 0, 15, 0]})],
		[0.5, _m(G, {"LL": [-5, 4, 18, 0], "RL": [8, 18, 28, 0], "hy": -0.09})],
		[1.0, _m(G, {"LL": [-10, 22, 25, 0], "RL": [5, 0, 15, 0]})]]]
	d["jump"] = [0.5, false, [
		[0.0, _m(R, {"LL": [10, 3, 30, 0], "RL": [10, 3, 30, 0], "hy": -0.1})],
		[0.4, _m(R, {"L": [40, 30, 0, 40], "R": [40, 30, 0, 40], "LL": [35, 4, 60, 20], "RL": [10, 4, 40, 20]})],
		[1.0, _m(R, {"L": [35, 20, 0, 40], "R": [35, 20, 0, 40], "LL": [25, 4, 50, 20], "RL": [5, 4, 30, 20]})]]]
	d["fall"] = [0.8, true, [
		[0.0, _m(R, {"L": [20, 15, 0, 30], "R": [20, 15, 0, 30], "LL": [20, 6, 30, 10], "RL": [-5, 6, 20, 10]})],
		[0.5, _m(R, {"L": [15, 20, 0, 35], "R": [15, 20, 0, 35], "LL": [15, 6, 25, 10], "RL": [0, 6, 25, 10]})],
		[1.0, _m(R, {"L": [20, 15, 0, 30], "R": [20, 15, 0, 30], "LL": [20, 6, 30, 10], "RL": [-5, 6, 20, 10]})]]]
	var tuck := {"L": [30, 70, 0, 110], "R": [30, 70, 0, 110], "LL": [100, 6, 130, 30], "RL": [100, 6, 130, 30], "spine": [30, 0, 0], "chest": [25, 0, 0], "head": [30, 0, 0]}
	d["roll"] = [0.62, false, [
		[0.0, _m(G, {"hips": [10, 0, 0], "hy": -0.1})],
		[0.15, _m(tuck, {"hips": [80, 0, 0], "hy": -0.45, "hz": 0.2})],
		[0.35, _m(tuck, {"hips": [170, 0, 0], "hy": -0.5, "hz": 0.0})],
		[0.55, _m(tuck, {"hips": [260, 0, 0], "hy": -0.5, "hz": -0.2})],
		[0.75, _m(tuck, {"hips": [350, 0, 0], "hy": -0.35})],
		[1.0, _m(G, {"hips": [360, 0, 0], "hy": -0.08})]]]
	d["backstep"] = [0.45, false, [
		[0.0, G], [0.3, _m(G, {"spine": [-12, 0, 0], "LL": [25, 6, 30, 0], "RL": [-20, 6, 10, 0], "hy": 0.05, "hz": -0.1})], [1.0, G]]]
	d["guard"] = [1.0, true, [
		[0.0, {"L": [35, 80, 0, 95, 0], "R": [55, 40, 30, 80, 0], "LL": [-18, 10, 30, -10], "RL": [15, 8, 25, 0], "spine": [12, 15, 0], "hy": -0.12}],
		[1.0, {"L": [35, 80, 0, 95, 0], "R": [55, 40, 30, 80, 0], "LL": [-18, 10, 30, -10], "RL": [15, 8, 25, 0], "spine": [12, 15, 0], "hy": -0.12}]]]
	d["hit"] = [0.4, false, [
		[0.0, G], [0.25, _m(G, {"spine": [-18, 8, 6], "head": [-20, 0, 0], "L": [50, -10, 0, 40], "R": [50, -10, 0, 40]})], [1.0, G]]]
	d["knockdown"] = [1.6, false, [
		[0.0, G],
		[0.18, _m(R, {"hips": [-40, 0, 0], "hy": -0.3, "spine": [-20, 0, 0], "L": [20, 30, 0, 30], "R": [20, 30, 0, 30], "LL": [50, 10, 30, 0], "RL": [40, 10, 20, 0]})],
		[0.35, _m(R, {"hips": [-85, 0, 0], "hy": -0.85, "L": [70, 0, 0, 10], "R": [70, 0, 0, 10], "LL": [10, 10, 10, 0], "RL": [15, 10, 20, 0]})],
		[0.7, _m(R, {"hips": [-85, 0, 0], "hy": -0.85, "L": [70, 0, 0, 10], "R": [70, 0, 0, 10], "LL": [10, 10, 10, 0], "RL": [15, 10, 20, 0]})],
		[0.85, _m(R, {"hips": [0, 0, 0], "hy": -0.5, "LL": [80, 8, 120, 0], "RL": [-10, 8, 100, 40], "spine": [30, 0, 0]})],
		[1.0, G]]]
	var dead := _m(R, {"hips": [-88, 0, 0], "hy": -0.86, "L": [70, -10, 0, 20], "R": [60, 10, 0, 30], "LL": [5, 12, 10, 0], "RL": [10, 8, 25, 0], "head": [0, 30, 0]})
	d["death"] = [1.0, false, [[0.0, G], [0.3, _m(R, {"hips": [-40, 0, 0], "hy": -0.4, "LL": [40, 8, 70, 0], "RL": [30, 8, 60, 0]})], [1.0, dead]]]
	d["lie"] = [2.0, true, [[0.0, dead], [1.0, dead]]]
	var sit := _m(R, {"hips": [-10, 0, 0], "hy": -0.78, "LL": [85, 10, 25, 0], "RL": [80, 6, 60, 0], "spine": [25, 0, 0], "L": [60, -30, 0, 10], "R": [70, 10, 0, 60], "head": [10, 0, 0]})
	d["sit_up"] = [1.4, false, [[0.0, dead], [0.6, _m(sit, {"spine": [-10, 0, 0], "hy": -0.82})], [1.0, sit]]]
	d["sit"] = [2.0, true, [[0.0, sit], [1.0, sit]]]
	var kneel := _m(R, {"hy": -0.42, "LL": [90, 6, 95, 0], "RL": [-15, 6, 110, 40], "spine": [15, 0, 0], "L": [70, 40, 0, 50], "R": [55, 30, 0, 30], "head": [20, 0, 0]})
	d["kneel"] = [2.0, true, [[0.0, kneel], [1.0, kneel]]]
	d["talk"] = [2.4, true, [
		[0.0, R], [0.3, _m(R, {"R": [45, 45, -30, 60, 10], "head": [0, -5, 3]})], [0.6, _m(R, {"R": [55, 30, -20, 50, -10], "chest": [-3, 4, 0]})], [1.0, R]]]
	d["wave"] = [1.2, true, [
		[0.0, _m(R, {"R": [-40, 20, 0, 60, 20]})], [0.5, _m(R, {"R": [-40, 20, 0, 40, -20]})], [1.0, _m(R, {"R": [-40, 20, 0, 60, 20]})]]]
	d["cheer"] = [1.0, false, [[0.0, R], [0.4, _m(R, {"L": [-60, 10, 0, 20], "R": [-60, 10, 0, 20], "head": [-15, 0, 0], "hy": 0.05})], [1.0, R]]]
	d["roar"] = [1.0, false, [[0.0, G], [0.3, _m(G, {"spine": [-20, 0, 0], "head": [-25, 0, 0], "L": [20, -20, 0, 40], "R": [20, -20, 0, 40]})], [1.0, G]]]
	d["bow"] = [1.6, false, [[0.0, R], [0.4, _m(R, {"spine": [35, 0, 0], "head": [20, 0, 0], "R": [70, 60, 0, 100]})], [0.7, _m(R, {"spine": [35, 0, 0], "head": [20, 0, 0], "R": [70, 60, 0, 100]})], [1.0, R]]]
	# Swimming: treading water upright, and a breaststroke with the body near horizontal.
	d["swim_idle"] = [2.0, true, [
		[0.0, {"L": [20, 30, 0, 30, 0], "R": [20, 30, 0, 30, 0], "LL": [20, 10, 40, 30], "RL": [0, 10, 20, 30], "hy": -0.05}],
		[0.5, {"L": [30, 0, 0, 20, 0], "R": [30, 0, 0, 20, 0], "LL": [0, 10, 20, 30], "RL": [20, 10, 40, 30], "hy": -0.1}],
		[1.0, {"L": [20, 30, 0, 30, 0], "R": [20, 30, 0, 30, 0], "LL": [20, 10, 40, 30], "RL": [0, 10, 20, 30], "hy": -0.05}]]]
	var sw := {"hips": [75, 0, 0], "head": [-55, 0, 0], "neck": [-15, 0, 0], "hy": -0.6}
	d["swim"] = [1.1, true, [
		[0.0, _m(sw, {"L": [-80, 100, 0, 10, 0], "R": [-80, 100, 0, 10, 0], "LL": [-5, 6, 5, 40], "RL": [-5, 6, 5, 40]})],
		[0.35, _m(sw, {"L": [30, 70, 0, 20, 0], "R": [30, 70, 0, 20, 0], "LL": [10, 20, 80, 30], "RL": [10, 20, 80, 30]})],
		[0.65, _m(sw, {"L": [70, 20, 0, 110, 0], "R": [70, 20, 0, 110, 0], "LL": [0, 25, 20, 50], "RL": [0, 25, 20, 50]})],
		[1.0, _m(sw, {"L": [-80, 100, 0, 10, 0], "R": [-80, 100, 0, 10, 0], "LL": [-5, 6, 5, 40], "RL": [-5, 6, 5, 40]})]]]
	d["dive"] = [1.0, true, [
		[0.0, _m(sw, {"hips": [110, 0, 0], "L": [-80, 100, 0, 10, 0], "R": [-80, 100, 0, 10, 0], "LL": [-10, 6, 10, 50], "RL": [10, 6, 30, 50]})],
		[0.5, _m(sw, {"hips": [110, 0, 0], "L": [-70, 100, 0, 10, 0], "R": [-70, 100, 0, 10, 0], "LL": [10, 6, 30, 50], "RL": [-10, 6, 10, 50]})],
		[1.0, _m(sw, {"hips": [110, 0, 0], "L": [-80, 100, 0, 10, 0], "R": [-80, 100, 0, 10, 0], "LL": [-10, 6, 10, 50], "RL": [10, 6, 30, 50]})]]]
	d["gather"] = [1.4, true, [[0.0, kneel], [0.5, _m(kneel, {"R": [50, 80, 0, 30, 0], "L": [50, 80, 0, 30, 0], "spine": [35, 0, 0]})], [1.0, kneel]]]
	d["drink"] = [1.1, false, [[0.0, R], [0.4, _m(R, {"R": [60, 70, 0, 140, 0], "head": [-25, 0, 0]})], [0.8, _m(R, {"R": [60, 70, 0, 140, 0], "head": [-25, 0, 0]})], [1.0, R]]]
	d["dash"] = [0.6, true, [[0.0, _m(G, {"spine": [25, 0, 0], "L": [40, -30, 0, 40], "R": [40, -30, 0, 40], "LL": [30, 6, 60, 0], "RL": [-30, 6, 30, 0], "hy": -0.15})],
		[1.0, _m(G, {"spine": [25, 0, 0], "L": [40, -30, 0, 40], "R": [40, -30, 0, 40], "LL": [30, 6, 60, 0], "RL": [-30, 6, 30, 0], "hy": -0.15})]]]
	d["leap"] = [1.0, false, [
		[0.0, _m(G, {"hy": -0.25, "LL": [40, 6, 80, 0], "RL": [40, 6, 80, 0], "spine": [20, 0, 0]})],
		[0.3, _m(G, {"R": [-30, 40, 0, 20], "L": [20, 30, 0, 30], "LL": [50, 6, 90, 20], "RL": [10, 6, 60, 20]})],
		[0.65, _m(G, {"R": [-60, 50, 0, 10], "L": [10, 30, 0, 30], "LL": [60, 6, 100, 20], "RL": [30, 6, 90, 20], "spine": [-10, 0, 0]})],
		[0.78, _m(G, {"R": [60, 90, 0, 10], "spine": [40, 0, 0], "LL": [60, 8, 90, 0], "RL": [-20, 8, 40, 0], "hy": -0.35})],
		[1.0, G]]]
	_attacks(d, G)
	return d


## Locomotion cycle: thigh swing, knee lift, bob, arm [down, swing, twist, elbow], lean.
static func _cycle(swing: float, knee: float, bob: float, arm: Array, lean: float, hy0 := 0.0) -> Array:
	var keys := []
	for i in 5:
		var t := i / 4.0
		var ph := t * TAU
		var s := sin(ph)
		var c := cos(ph)
		var lf := s * swing
		var rf := -s * swing
		var lk: float = knee + maxf(0.0, -c) * knee * 3.5 + (maxf(0.0, -s) * swing * 0.6)
		var rk: float = knee + maxf(0.0, c) * knee * 3.5 + (maxf(0.0, s) * swing * 0.6)
		keys.append([t, {
			"LL": [lf, 3, lk, -lf * 0.3], "RL": [rf, 3, rk, -rf * 0.3],
			"L": [arm[0], -s * arm[1], arm[2], arm[3], 0], "R": [arm[0], s * arm[1], arm[2], arm[3], 0],
			"spine": [lean, s * 4.0, 0], "chest": [0, s * 5.0, 0], "head": [-lean * 0.6, -s * 4.0, 0],
			"hy": hy0 - absf(c) * bob + bob * 0.5}])
	return keys


## Attack animations. All are 1.0 s long and are time-scaled to the move duration.
## Phases: wind-up 0-0.3, strike 0.3-0.5, follow-through 0.5-0.8, recover 0.8-1.0.
static func _attacks(d: Dictionary, G: Dictionary) -> void:
	var stance := {"LL": [14, 8, 26, -10], "RL": [-12, 8, 14, 6], "hy": -0.08}
	var lunge := {"LL": [34, 8, 48, -14], "RL": [-24, 8, 12, 12], "hy": -0.16, "hz": 0.12}
	var A := func(wind: Dictionary, strike: Dictionary, follow: Dictionary) -> Array:
		return [1.0, false, [[0.0, G], [0.28, _m(_m(G, stance), wind)], [0.42, _m(_m(G, lunge), strike)], [0.7, _m(_m(G, lunge), follow)], [1.0, G]]]
	d["slash_r"] = A.call({"R": [30, -40, 20, 70, 20], "spine": [5, -35, 0], "L": [60, 40, 0, 60]},
		{"R": [70, 90, -10, 15, -10], "spine": [12, 30, 0], "L": [70, -10, 0, 30]},
		{"R": [80, 140, -30, 10, -20], "spine": [14, 40, 0], "L": [72, -20, 0, 30]})
	d["slash_l"] = A.call({"R": [75, 140, -40, 40, -10], "spine": [8, 35, 0], "L": [60, 20, 0, 40]},
		{"R": [60, 50, 30, 10, 20], "spine": [12, -20, 0], "L": [70, 10, 0, 30]},
		{"R": [45, -20, 40, 15, 30], "spine": [10, -35, 0], "L": [72, 30, 0, 30]})
	d["slash_down"] = A.call({"R": [-70, 40, 0, 70, 0], "L": [-50, 40, 0, 80], "spine": [-15, -10, 0], "head": [-10, 0, 0]},
		{"R": [40, 90, 0, 10, 0], "L": [45, 80, 0, 30], "spine": [30, 0, 0]},
		{"R": [75, 70, 0, 10, 0], "L": [70, 60, 0, 30], "spine": [35, 0, 0], "hy": -0.22})
	d["slash_up"] = A.call({"R": [85, -10, 0, 20, -20], "spine": [25, -20, 0], "hy": -0.2},
		{"R": [-20, 80, 0, 10, 20], "spine": [-15, 10, 0], "hy": 0.02},
		{"R": [-60, 60, 0, 30, 0], "spine": [-20, 15, 0]})
	d["thrust"] = A.call({"R": [60, -10, 0, 120, 0], "L": [40, 60, 0, 90], "spine": [0, -30, 0]},
		{"R": [5, 90, 0, 0, 0], "L": [15, 75, 0, 20], "spine": [18, -15, 0]},
		{"R": [10, 85, 0, 5, 0], "L": [20, 70, 0, 25], "spine": [20, -15, 0]})
	d["thrust_big"] = A.call({"R": [60, -30, 0, 130, 0], "L": [30, 60, 0, 100], "spine": [-5, -45, 0], "hy": -0.18},
		{"R": [0, 95, 0, 0, 0], "L": [10, 80, 0, 10], "spine": [25, -10, 0], "hz": 0.3},
		{"R": [5, 90, 0, 0, 0], "L": [15, 80, 0, 15], "spine": [25, -10, 0], "hz": 0.3})
	d["heavy_side"] = A.call({"R": [20, -70, 30, 60, 0], "L": [20, -40, 0, 70], "spine": [0, -60, 0], "hy": -0.15},
		{"R": [60, 80, 0, 10, 0], "L": [55, 90, 0, 20], "spine": [15, 30, 0]},
		{"R": [70, 150, 0, 10, 0], "L": [70, 140, 0, 20], "spine": [20, 55, 0], "hy": -0.2})
	d["heavy_side_back"] = A.call({"R": [70, 150, 0, 30, 0], "L": [70, 140, 0, 30], "spine": [10, 60, 0], "hy": -0.15},
		{"R": [55, 60, 0, 10, 0], "L": [55, 60, 0, 20], "spine": [15, -10, 0]},
		{"R": [40, -50, 0, 10, 0], "L": [40, -30, 0, 20], "spine": [10, -50, 0], "hy": -0.2})
	d["heavy_down"] = [1.0, false, [[0.0, G],
		[0.35, _m(_m(G, stance), {"R": [-90, 30, 0, 80, 0], "L": [-85, 30, 0, 80], "spine": [-25, 0, 0], "head": [-15, 0, 0], "hy": -0.04})],
		[0.5, _m(_m(G, lunge), {"R": [50, 90, 0, 10, 0], "L": [50, 85, 0, 10], "spine": [40, 0, 0], "hy": -0.28})],
		[0.8, _m(_m(G, lunge), {"R": [80, 70, 0, 10, 0], "L": [78, 65, 0, 10], "spine": [45, 0, 0], "hy": -0.3})], [1.0, G]]]
	d["heavy_up"] = A.call({"R": [80, -20, 0, 20, 0], "L": [80, -10, 0, 30], "spine": [35, -25, 0], "hy": -0.3},
		{"R": [-60, 70, 0, 10, 0], "L": [-55, 70, 0, 20], "spine": [-20, 10, 0], "hy": 0.05},
		{"R": [-80, 50, 0, 20, 0], "L": [-75, 50, 0, 30], "spine": [-25, 10, 0]})
	d["spin"] = [1.0, false, [[0.0, G],
		[0.2, _m(_m(G, stance), {"R": [10, -60, 0, 20], "spine": [5, -50, 0], "hips": [0, -40, 0]})],
		[0.4, _m(_m(G, lunge), {"R": [10, 90, 0, 10], "L": [10, -90, 0, 10], "hips": [0, 90, 0], "spine": [10, 20, 0]})],
		[0.6, _m(_m(G, lunge), {"R": [10, 90, 0, 10], "L": [10, -90, 0, 10], "hips": [0, 220, 0], "spine": [10, 20, 0]})],
		[0.8, _m(_m(G, lunge), {"R": [30, 90, 0, 10], "L": [30, -60, 0, 10], "hips": [0, 340, 0]})],
		[1.0, _m(G, {"hips": [0, 360, 0]})]]]
	d["bash"] = A.call({"L": [50, 30, 0, 110], "spine": [0, 30, 0], "R": [60, 0, 0, 60]},
		{"L": [40, 95, 0, 20], "spine": [15, -25, 0], "R": [60, -20, 0, 60]},
		{"L": [45, 90, 0, 25], "spine": [15, -25, 0], "R": [60, -20, 0, 60]})
	d["slam"] = A.call({"R": [-80, 30, 0, 90], "L": [-80, 30, 0, 90], "spine": [-20, 0, 0], "hy": 0.05},
		{"R": [40, 85, 0, 20], "L": [40, 85, 0, 20], "spine": [45, 0, 0], "hy": -0.4},
		{"R": [60, 80, 0, 20], "L": [60, 80, 0, 20], "spine": [45, 0, 0], "hy": -0.4})
	d["punch_r"] = A.call({"R": [60, -20, 0, 130, 0], "L": [45, 70, 0, 110], "spine": [0, -25, 0]},
		{"R": [10, 92, 0, 0, 0], "L": [50, 40, 0, 120], "spine": [10, 25, 0]},
		{"R": [15, 88, 0, 5, 0], "L": [50, 40, 0, 120], "spine": [10, 25, 0]})
	d["punch_l"] = A.call({"L": [60, -20, 0, 130, 0], "R": [45, 70, 0, 110], "spine": [0, 25, 0]},
		{"L": [10, 92, 0, 0, 0], "R": [50, 40, 0, 120], "spine": [10, -25, 0]},
		{"L": [15, 88, 0, 5, 0], "R": [50, 40, 0, 120], "spine": [10, -25, 0]})
	d["kick"] = A.call({"RL": [40, 10, 100, 0], "LL": [-5, 8, 20, 0], "spine": [-10, -20, 0], "L": [50, 60, 0, 90], "R": [50, 60, 0, 90]},
		{"RL": [85, 20, 5, 30], "LL": [-10, 8, 25, 0], "spine": [-25, -40, 0], "hips": [0, -30, 0]},
		{"RL": [70, 20, 20, 20], "LL": [-10, 8, 25, 0], "spine": [-20, -40, 0], "hips": [0, -30, 0]})
	d["cast"] = A.call({"R": [50, 20, 0, 110, 0], "L": [60, 30, 0, 90], "spine": [-5, -15, 0]},
		{"R": [0, 90, 0, 0, -30], "L": [65, 30, 0, 80], "spine": [8, 10, 0]},
		{"R": [5, 88, 0, 5, -30], "L": [65, 30, 0, 80], "spine": [8, 10, 0]})
	d["cast_l"] = A.call({"L": [50, 20, 0, 110, 0], "R": [60, 30, 0, 90], "spine": [-5, 15, 0]},
		{"L": [0, 90, 0, 0, -30], "R": [65, 30, 0, 80], "spine": [8, -10, 0]},
		{"L": [5, 88, 0, 5, -30], "R": [65, 30, 0, 80], "spine": [8, -10, 0]})
	d["cast_up"] = A.call({"R": [40, 60, 0, 100], "L": [40, 60, 0, 100], "spine": [10, 0, 0], "head": [10, 0, 0]},
		{"R": [-75, 40, 0, 10], "L": [-75, 40, 0, 10], "spine": [-15, 0, 0], "head": [-20, 0, 0], "hy": 0.03},
		{"R": [-10, 80, 0, 10], "L": [-10, 80, 0, 10], "spine": [10, 0, 0]})
	d["heal"] = A.call({"R": [60, 70, 0, 90], "L": [60, 70, 0, 90], "head": [15, 0, 0]},
		{"R": [-30, 60, 0, 30], "L": [-30, 60, 0, 30], "head": [-15, 0, 0], "spine": [-8, 0, 0]},
		{"R": [-20, 50, 0, 30], "L": [-20, 50, 0, 30], "head": [-10, 0, 0]})
	d["buff_pose"] = A.call({"R": [60, 60, 0, 120], "L": [60, 60, 0, 120], "spine": [15, 0, 0], "hy": -0.12},
		{"R": [-40, -20, 0, 40], "L": [-40, -20, 0, 40], "spine": [-15, 0, 0], "head": [-15, 0, 0]},
		{"R": [-30, -10, 0, 50], "L": [-30, -10, 0, 50], "spine": [-10, 0, 0]})
	d["summon"] = A.call({"R": [60, 60, 0, 120], "L": [60, 60, 0, 120], "spine": [25, 0, 0], "hy": -0.15},
		{"R": [-85, 20, 0, 5], "L": [-85, 20, 0, 5], "spine": [-20, 0, 0], "head": [-30, 0, 0]},
		{"R": [-80, 20, 0, 5], "L": [-80, 20, 0, 5], "spine": [-20, 0, 0], "head": [-30, 0, 0]})
	d["mudra"] = A.call({"R": [60, 80, 0, 120, 0], "L": [60, 80, 0, 120, 0], "spine": [10, 0, 0]},
		{"R": [60, 85, 0, 130, 30], "L": [60, 85, 0, 130, -30]},
		{"R": [10, 90, 0, 0, 0], "L": [70, 40, 0, 90], "spine": [10, 10, 0]})
	d["shoot_bow"] = A.call({"L": [5, 85, 0, 0, 0], "R": [10, 75, 0, 140, 0], "spine": [0, -60, 0], "head": [0, 55, 0]},
		{"L": [5, 85, 0, 0, 0], "R": [5, -20, 0, 160, 0], "spine": [0, -65, 0], "head": [0, 60, 0]},
		{"L": [8, 85, 0, 0, 0], "R": [30, -40, 0, 60, 0], "spine": [0, -60, 0], "head": [0, 55, 0]})
	d["shoot_bow_charge"] = d["shoot_bow"]
	d["shoot_up"] = A.call({"L": [-40, 70, 0, 0, 0], "R": [-30, 50, 0, 140, 0], "spine": [-20, -50, 0], "head": [-30, 45, 0]},
		{"L": [-45, 70, 0, 0, 0], "R": [-20, -20, 0, 160, 0], "spine": [-25, -55, 0], "head": [-35, 50, 0]},
		{"L": [-40, 70, 0, 0, 0], "R": [20, -30, 0, 60, 0], "spine": [-20, -50, 0]})
	d["shoot_gun"] = A.call({"R": [10, 85, 0, 10, 0], "L": [15, 80, 0, 30, 0], "spine": [0, -20, 0], "head": [0, 15, 0]},
		{"R": [-5, 85, 0, 30, 0], "L": [5, 80, 0, 40, 0], "spine": [-5, -15, 0]},
		{"R": [5, 85, 0, 15, 0], "L": [15, 80, 0, 30, 0], "spine": [0, -20, 0]})
	d["shoot_gun_heavy"] = A.call({"R": [20, 80, 0, 20, 0], "L": [20, 80, 0, 40, 0], "spine": [10, -25, 0], "hy": -0.15},
		{"R": [-20, 80, 0, 60, 0], "L": [-10, 80, 0, 60, 0], "spine": [-15, -20, 0], "hz": -0.2},
		{"R": [10, 80, 0, 20, 0], "L": [15, 80, 0, 40, 0], "spine": [5, -25, 0]})
	d["throw"] = A.call({"R": [20, -60, 0, 60, 0], "spine": [0, -40, 0], "L": [60, 60, 0, 60]},
		{"R": [40, 100, 0, 5, -20], "spine": [10, 30, 0], "L": [70, -10, 0, 30]},
		{"R": [60, 130, 0, 10, -20], "spine": [10, 40, 0]})
	d["throw_l"] = A.call({"L": [20, -60, 0, 60, 0], "spine": [0, 40, 0], "R": [60, 60, 0, 60]},
		{"L": [40, 100, 0, 5, -20], "spine": [10, -30, 0], "R": [70, -10, 0, 30]},
		{"L": [60, 130, 0, 10, -20], "spine": [10, -40, 0]})
	d["dance"] = [1.0, false, [[0.0, G],
		[0.25, {"R": [-60, 30, 0, 30], "L": [20, -30, 0, 40], "hips": [0, 120, 0], "LL": [-10, 20, 40, 30], "RL": [20, 10, 20, 0]}],
		[0.5, {"R": [10, -30, 0, 40], "L": [-60, 30, 0, 30], "hips": [0, 240, 0], "LL": [20, 10, 20, 0], "RL": [-10, 20, 40, 30]}],
		[0.75, {"R": [-70, 10, 0, 10], "L": [-70, 10, 0, 10], "hips": [0, 360, 0], "head": [-20, 0, 0], "hy": 0.04}],
		[1.0, _m(G, {"hips": [0, 360, 0]})]]]
	d["iai"] = [1.0, false, [[0.0, G],
		[0.5, _m(G, {"R": [70, -10, 0, 80, 0], "L": [70, 10, 0, 70, 0], "spine": [20, 25, 0], "LL": [-40, 10, 60, -10], "RL": [30, 10, 30, 0], "hy": -0.28})],
		[0.68, _m(G, {"R": [55, 160, 0, 5, 0], "L": [70, -40, 0, 20], "spine": [18, -40, 0], "LL": [-45, 10, 65, -10], "RL": [35, 10, 30, 0], "hy": -0.3, "hz": 0.4})],
		[0.85, _m(G, {"R": [60, 165, 0, 5, 0], "L": [70, -40, 0, 20], "spine": [18, -40, 0], "hy": -0.28, "hz": 0.4})],
		[1.0, G]]]
	d["swell"] = d["roar"]
