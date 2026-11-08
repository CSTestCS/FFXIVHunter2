class_name CamShots
## Conversation cinematography. Builds a camera move (start transform -> end transform, with
## field of view) for a named shot type, framed on the speaker's real head and placed on a
## consistent side of the speaker/listener line (the 180-degree rule) so cuts read naturally.
## Every shot drifts slightly over its duration (push-in, slide or arc) to keep scenes alive.
##
## Types: closeup, ots (over the listener's shoulder), two (two-shot), profile, low (heroic
## low angle), high (looking down), wide (establishing).

const TYPES := ["closeup", "ots", "two", "profile", "low", "high", "wide"]


## Returns {"from": Transform3D, "to": Transform3D, "fov_from": float, "fov_to": float}
static func make(type: String, speaker: CharModel, listener: CharModel, side_sign: float, world: Node) -> Dictionary:
	var h := speaker.head_pos()
	var k := clampf(speaker.scale.y, 0.6, 1.25)
	var lh: Vector3
	var fwd := -speaker.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	if listener and is_instance_valid(listener) and listener != speaker:
		lh = listener.head_pos()
	else:
		lh = h + fwd * 2.0
	var ax := lh - h
	ax.y = 0
	ax = ax.normalized() if ax.length() > 0.05 else fwd
	var side := Vector3(-ax.z, 0, ax.x) * side_sign
	var up := Vector3.UP
	var mid := (h + lh) * 0.5
	var look := h
	var p: Vector3
	var drift: Vector3
	var fov := 38.0
	var fov_end := 36.0
	match type:
		"closeup":
			p = h + ax * 1.05 * k + side * 0.32 * k + up * 0.02
			drift = (h - p) * 0.14
			fov = 32.0; fov_end = 30.0
		"ots":
			p = lh + ax * 0.6 + side * 0.48 + up * 0.14
			drift = side * 0.14
			fov = 38.0; fov_end = 36.0
		"two":
			var d := maxf(2.4, h.distance_to(lh) * 1.25)
			p = mid + side * d + up * 0.18
			look = mid
			drift = ax * 0.35
			fov = 44.0; fov_end = 42.0
		"profile":
			p = h + side * 1.25 * k + ax * 0.3 * k
			drift = (p - h).rotated(Vector3.UP, deg_to_rad(10.0 * side_sign)) + h - p
			fov = 34.0; fov_end = 33.0
		"low":
			p = h + ax * 1.45 * k + side * 0.45 * k - up * 0.6 * k
			look = h + up * 0.06
			drift = (h - p) * 0.1 + up * 0.08
			fov = 40.0; fov_end = 38.0
		"high":
			p = h + ax * 1.6 * k + side * 0.55 + up * 1.15
			drift = (h - p) * 0.12
			fov = 40.0; fov_end = 38.0
		_:  # wide
			p = mid + side * 4.2 + ax * -1.2 + up * 1.4
			look = mid - up * 0.3
			drift = side * 0.5
			fov = 50.0; fov_end = 48.0
	# Wider shots are meant to include the listener; tight shots must not be blocked by them.
	var allowed: Array = [speaker]
	if type in ["ots", "two", "wide"] and listener: allowed.append(listener)
	if world:
		p = _settle(world, look, p, allowed)
	var p2 := p + drift
	if world:
		p2 = _settle(world, look, p2, allowed)
	return {"from": Transform3D(Basis(), p).looking_at(look, Vector3.UP),
		"to": Transform3D(Basis(), p2).looking_at(look, Vector3.UP), "fov_from": fov, "fov_to": fov_end}


static func _settle(world: Node, look: Vector3, p: Vector3, allowed: Array) -> Vector3:
	p.y = maxf(p.y, world.ground_height(p.x, p.z) + 0.3)
	return world.clear_shot(look, p, [], allowed)


## Picks a shot for the next line: a new speaker gets a reverse angle (over-the-shoulder or
## close-up); the same speaker continuing gets a different, tighter or more dramatic angle.
static func pick(new_speaker: bool, expr: String, n: int, last: String) -> String:
	var pool: Array
	if new_speaker:
		pool = ["ots", "closeup", "ots", "two", "profile"]
	else:
		pool = ["closeup", "profile", "low", "high", "two"]
	match expr:
		"angry": pool.append_array(["low", "closeup"])
		"sorrow": pool.append_array(["high", "profile"])
		"surprised": pool.append_array(["closeup", "closeup"])
		"joy", "fun": pool.append_array(["two", "ots"])
	var t: String = pool[(n * 7 + 3) % pool.size()]
	if t == last: t = pool[(n * 7 + 4) % pool.size()]
	return t
