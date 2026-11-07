extends Node
## Procedurally synthesised sound effects and ambient music loops (no audio files to ship).
## Sounds are generated once, lazily, and played through small reusable player pools.

const RATE := 22050
var _cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _music: AudioStreamPlayer
var _music_id := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new(); add_child(p); _pool.append(p)
	_music = AudioStreamPlayer.new(); add_child(_music)


func play(id: String, vol := 0.0, pitch := 1.0) -> void:
	var s := _stream(id)
	for p in _pool:
		if not p.playing:
			p.stream = s; p.volume_db = vol + linear_to_db(max(0.001, Settings.v["sfx"])); p.pitch_scale = pitch; p.play(); return


func play_at(id: String, pos: Vector3, vol := 0.0, pitch := 1.0) -> void:
	var tree := get_tree()
	if tree.current_scene == null: return
	var p: AudioStreamPlayer3D = null
	for q in _pool3d:
		if is_instance_valid(q) and not q.playing and q.is_inside_tree(): p = q; break
	if p == null:
		if _pool3d.size() >= 12:
			_pool3d = _pool3d.filter(func(x): return is_instance_valid(x))
			if _pool3d.size() >= 12: return
		p = AudioStreamPlayer3D.new(); p.max_distance = 60.0; p.unit_size = 6.0
		tree.current_scene.add_child(p); _pool3d.append(p)
	p.global_position = pos
	p.stream = _stream(id); p.volume_db = vol + linear_to_db(max(0.001, Settings.v["sfx"])); p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.play()


func music(mood: String) -> void:
	if mood == _music_id: return
	_music_id = mood
	if mood == "":
		_music.stop(); return
	_music.stream = _stream("music_" + mood)
	_music.volume_db = linear_to_db(max(0.001, Settings.v["music"])) - 8.0
	_music.play()


func _stream(id: String) -> AudioStreamWAV:
	if not _cache.has(id): _cache[id] = _make(id)
	return _cache[id]


func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var b := PackedByteArray(); b.resize(samples.size() * 2)
	for i in samples.size(): b.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.data = b
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_end = samples.size()
	return w


func _make(id: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new(); rng.seed = hash(id)
	if id.begins_with("music_"): return _make_music(id.substr(6), rng)
	# [duration, start freq, end freq, noise mix, decay, harmonic]
	var p: Array = {
		"hit": [0.16, 220.0, 70.0, 0.55, 18.0, 0.3], "heavy": [0.32, 140.0, 40.0, 0.6, 9.0, 0.5],
		"swing": [0.18, 900.0, 300.0, 0.9, 12.0, 0.0], "cast": [0.5, 500.0, 1400.0, 0.15, 4.0, 0.6],
		"boom": [0.8, 90.0, 30.0, 0.8, 4.0, 0.4], "roar": [1.1, 120.0, 70.0, 0.55, 2.5, 0.7],
		"ui_move": [0.05, 1300.0, 1300.0, 0.0, 40.0, 0.0], "ui_ok": [0.12, 880.0, 1320.0, 0.0, 18.0, 0.3],
		"ui_back": [0.12, 660.0, 440.0, 0.0, 18.0, 0.0], "coin": [0.25, 1760.0, 2350.0, 0.0, 10.0, 0.5],
		"splash": [0.45, 400.0, 150.0, 0.95, 6.0, 0.0], "block": [0.2, 1100.0, 900.0, 0.4, 16.0, 0.8],
		"levelup": [0.9, 523.0, 1046.0, 0.0, 2.5, 0.5], "step": [0.07, 120.0, 80.0, 0.8, 50.0, 0.0],
		"heal": [0.6, 660.0, 990.0, 0.05, 3.5, 0.6], "dodge": [0.2, 400.0, 200.0, 0.85, 14.0, 0.0],
	}.get(id, [0.1, 440.0, 440.0, 0.0, 20.0, 0.0])
	var n := int(p[0] * RATE)
	var s := PackedFloat32Array(); s.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		var f: float = lerpf(p[1], p[2], t)
		ph += TAU * f / RATE
		var tone := sin(ph) + float(p[5]) * sin(ph * 2.0) * 0.5
		var nz := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, nz, clampf(f / 3000.0, 0.05, 0.9))
		var env := exp(-t * float(p[4])) * minf(1.0, t * 200.0)
		s[i] = (tone * (1.0 - float(p[3])) + lp * float(p[3]) * 1.6) * env * 0.6
	return _wav(s)


## Slow ambient pad loops (12 s) built from a chord progression per mood.
func _make_music(mood: String, rng: RandomNumberGenerator) -> AudioStreamWAV:
	var prog: Array = {
		"forest": [[57, 60, 64, 69], [53, 57, 60, 65], [55, 59, 62, 67], [52, 55, 59, 64]],
		"sea": [[50, 57, 62, 66], [55, 59, 62, 67], [57, 61, 64, 69], [54, 57, 62, 66]],
		"desert": [[52, 59, 63, 64], [53, 57, 60, 64], [52, 56, 59, 64], [50, 57, 60, 65]],
		"snow": [[50, 57, 62, 65], [46, 53, 58, 62], [48, 55, 60, 63], [45, 52, 57, 60]],
		"crystal": [[49, 56, 61, 64], [47, 54, 59, 63], [45, 52, 57, 61], [44, 51, 56, 59]],
		"battle": [[45, 52, 57, 60], [41, 48, 53, 57], [43, 50, 55, 59], [40, 47, 52, 56]],
		"title": [[52, 59, 64, 67], [48, 55, 60, 64], [50, 57, 62, 66], [47, 54, 59, 62]],
	}.get(mood, [[57, 60, 64, 69]])
	var seg := 3.0
	var n := int(seg * prog.size() * RATE)
	var s := PackedFloat32Array(); s.resize(n)
	var seg_n := int(seg * RATE)
	var phases := [0.0, 0.0, 0.0, 0.0, 0.0]
	for i in n:
		var ci := (i / seg_n) % prog.size()
		var local := float(i % seg_n) / seg_n
		var env := sin(local * PI) * 0.8 + 0.2
		var chord: Array = prog[ci]
		var v := 0.0
		for k in 4:
			var f := 440.0 * pow(2.0, (float(chord[k]) - 69.0) / 12.0)
			phases[k] += TAU * f / RATE
			v += sin(phases[k]) * (0.5 if k == 0 else 0.28) + sin(phases[k] * 2.0) * 0.04
		# soft arpeggio bell on top
		var step := int(local * 8.0) % 4
		var bf := 440.0 * pow(2.0, (float(chord[step]) + 12.0 - 69.0) / 12.0)
		phases[4] += TAU * bf / RATE
		var bell_env := exp(-fmod(local * 8.0, 1.0) * 5.0)
		v += sin(phases[4]) * bell_env * (0.12 if mood != "battle" else 0.2)
		s[i] = v * env * 0.16
	return _wav(s, true)
