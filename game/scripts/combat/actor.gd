class_name Actor
extends CharacterBody3D
## Base for anything that fights: player, companions, monsters.

var display_name := "?"
var team := 0                 # 0 = adventurers, 1 = hostile
var level := 1
var max_hp := 100.0
var hp := 100.0
var atk := 10.0
var defense := 0.0
var crit := 0.05
var dead := false
var invuln := 0.0             # i-frame timer
var guarding := false
var perfect_guard := 0.0      # timer: a guard started this recently negates damage entirely
var shield := 0.0
var buffs := {}               # name -> {amount, time}
var dots := []                # [{dps, time, src}]
var hots := []                # [{hps, time}]
var stagger := 0.0
var stagger_max := 100.0
var stun := 0.0
var slow := 0.0
var res := {}                 # element -> resistance 0..1
var world: Node
var radius := 0.5             # body radius used by hit tests
var gravity := 24.0


func buff(name: String) -> float:
	return float(buffs[name]["amount"]) if buffs.has(name) else 0.0


func add_buff(name: String, amount: float, time: float) -> void:
	buffs[name] = {"amount": amount, "time": time}


func center() -> Vector3:
	return global_position + Vector3(0, 1.0 * scale.y, 0)


func facing() -> Vector3:
	return -global_transform.basis.z


## Outgoing damage for a move of the given potency.
func roll_damage(potency: float) -> Dictionary:
	var c := randf() < crit + buff("crit")
	var amt := potency * atk * (1.0 + buff("dmg")) * randf_range(0.95, 1.05) * (1.5 if c else 1.0)
	return {"amount": amt, "crit": c}


## Returns {"dealt": int, "guarded": bool, "perfect": bool, "miss": bool}
func take_hit(info: Dictionary) -> Dictionary:
	if dead: return {"miss": true}
	if invuln > 0.0: return {"miss": true, "dodged": true}
	var amount: float = info.get("amount", 0.0)
	var src: Node3D = info.get("source")
	var guarded := false
	var perfect := false
	if guarding and src and info.get("can_guard", true):
		var to_src := (src.global_position - global_position)
		to_src.y = 0
		if to_src.length() < 0.01 or facing().dot(to_src.normalized()) > 0.2:
			guarded = true
			perfect = perfect_guard > 0.0
			amount *= 0.0 if perfect else 0.22
	amount *= 100.0 / (100.0 + defense)
	amount *= 1.0 - clampf(buff("def"), 0.0, 0.8)
	var elem: String = info.get("elem", "")
	if elem != "": amount *= 1.0 - clampf(float(res.get(elem, 0.0)) + float(res.get("all", 0.0)), 0.0, 0.8)
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed; amount -= absorbed
	var dealt := int(round(amount))
	hp = maxf(0.0, hp - dealt)
	if info.has("dot") and float(info["dot"]) > 0.0:
		dots.append({"dps": float(info["dot"]) * float(info.get("base", amount)) * 0.25, "time": 12.0})
	if info.has("slow"): slow = maxf(slow, 3.0)
	if world and world.has_method("on_hit"):
		world.on_hit(self, dealt, info.get("crit", false), guarded, perfect, team)
	if not guarded:
		stagger += float(info.get("stagger", 1.0)) * maxf(1.0, amount / max(1.0, max_hp) * 100.0)
		_on_hurt(info)
	if hp <= 0.0 and not dead:
		dead = true
		_on_death()
	return {"dealt": dealt, "guarded": guarded, "perfect": perfect, "miss": false}


func heal(amount: float, show := true) -> void:
	if dead: return
	var before := hp
	hp = minf(max_hp, hp + amount)
	if show and world and hp - before >= 1.0 and world.has_method("on_heal"): world.on_heal(self, int(hp - before))


func _on_hurt(_info: Dictionary) -> void:
	pass


func _on_death() -> void:
	pass


func tick_status(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	perfect_guard = maxf(0.0, perfect_guard - delta)
	stun = maxf(0.0, stun - delta)
	slow = maxf(0.0, slow - delta)
	stagger = maxf(0.0, stagger - delta * 6.0)
	for k in buffs.keys():
		buffs[k]["time"] = float(buffs[k]["time"]) - delta
		if buffs[k]["time"] <= 0.0: buffs.erase(k)
	if not dots.is_empty() and not dead:
		var d := 0.0
		for e in dots:
			d += float(e["dps"]) * delta; e["time"] = float(e["time"]) - delta
		dots = dots.filter(func(e): return e["time"] > 0.0)
		hp = maxf(1.0 if team == 0 else 0.0, hp - d)
		if hp <= 0.0 and not dead:
			dead = true; _on_death()
	if not hots.is_empty() and not dead:
		for e in hots:
			hp = minf(max_hp, hp + float(e["hps"]) * delta); e["time"] = float(e["time"]) - delta
		hots = hots.filter(func(e): return e["time"] > 0.0)
