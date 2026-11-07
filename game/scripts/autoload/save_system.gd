extends Node
## Multiple save slots stored as JSON in user://saves/. Each slot is independent.

const SLOTS := 8
const DIR := "user://saves"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func path(slot: int) -> String:
	return "%s/slot_%d.json" % [DIR, slot]


func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot))


func save_slot(slot: int, state: Dictionary) -> bool:
	state["saved_at"] = Time.get_datetime_string_from_system(false, true)
	var tmp := path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(state))
	f.close()
	# Write to a temp file first so a crash mid-save never corrupts the slot.
	DirAccess.rename_absolute(tmp, path(slot))
	return true


func load_slot(slot: int) -> Dictionary:
	if not exists(slot): return {}
	var f := FileAccess.open(path(slot), FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


func delete_slot(slot: int) -> void:
	if exists(slot): DirAccess.remove_absolute(path(slot))


## Summary shown on slot buttons.
func summary(slot: int) -> String:
	var d := load_slot(slot)
	if d.is_empty(): return "Slot %d  -  Empty" % (slot + 1)
	var job: String = d.get("job", "PLD")
	var lvl: int = int(d.get("jobs", {}).get(job, {}).get("level", 1))
	var zone: String = Data.zones.get(d.get("zone", ""), {}).get("name", "?")
	var pt := int(d.get("playtime", 0.0))
	return "Slot %d  -  %s   %s Lv.%d   %s   %dh %02dm   (%s)" % [slot + 1, d.get("name", "?"), Data.jobs[job]["name"], lvl,
		zone, pt / 3600, (pt / 60) % 60, str(d.get("saved_at", "")).replace("T", " ")]


func latest_slot() -> int:
	var best := -1
	var best_t := ""
	for i in SLOTS:
		if exists(i):
			var t := str(load_slot(i).get("saved_at", ""))
			if t > best_t: best_t = t; best = i
	return best
