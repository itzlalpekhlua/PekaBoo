extends Node
## All sounds are synthesised at startup, so the game ships with no audio files.

const RATE := 22050

var streams := {}
var _b := PackedFloat32Array()
var _pool: Array[AudioStreamPlayer] = []
var _next := 0


var steps := {}  # surface -> Array[AudioStream]
var ogg := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for surf in ["wood", "carpet", "grass", "concrete"]:
		var arr := []
		for k in 5:
			var path := "res://assets/sfx/footstep_%s_%03d.ogg" % [surf, k]
			if ResourceLoader.exists(path):
				arr.append(load(path))
		steps[surf] = arr
	steps["tile"] = steps["concrete"]
	steps["trampoline"] = steps["carpet"]
	for f in ["click_002", "confirmation_002", "error_004", "drop_002", "open_001", "close_001", "maximize_003", "pluck_001", "switch_002", "bong_001", "glitch_002", "impactPlank_medium_000", "impactSoft_heavy_000", "impactSoft_heavy_001"]:
		var path := "res://assets/sfx/%s.ogg" % f
		if ResourceLoader.exists(path):
			ogg[f] = load(path)
	streams["click"] = ogg.get("click_002")
	streams["confirm"] = ogg.get("confirmation_002")
	streams["error"] = ogg.get("error_004")
	streams["drop"] = ogg.get("drop_002")
	streams["open"] = ogg.get("open_001")
	streams["close"] = ogg.get("close_001")
	streams["whoosh"] = ogg.get("maximize_003")
	streams["thud"] = ogg.get("impactSoft_heavy_000")
	streams["thump"] = ogg.get("impactPlank_medium_000")
	streams["switch"] = ogg.get("switch_002")
	_build()
	_load_real()
	_setup_ambience()


func set_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(i, linear <= 0.001)


func footstep(surface: String, vol_db := -8.0) -> void:
	var arr: Array = steps.get(surface, steps.get("wood", []))
	if arr.is_empty():
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = arr[randi() % arr.size()]
	p.volume_db = vol_db
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()


func footstep_at(surface: String, pos: Vector3, vol_db := -4.0) -> void:
	var arr: Array = steps.get(surface, steps.get("wood", []))
	if arr.is_empty():
		return
	_spawn_3d(arr[randi() % arr.size()], pos, vol_db, randf_range(0.92, 1.08))


func _spawn_3d(stream: AudioStream, pos: Vector3, vol_db: float, pitch: float) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null or stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "SFX"
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.unit_size = 5.0
	p.max_distance = 40.0
	tree.current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func play(sound: String, vol_db := 0.0, pitch := 1.0) -> void:
	if streams.get(sound) == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = streams[sound]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func play_at(sound: String, pos: Vector3, vol_db := 0.0, pitch := 1.0) -> void:
	_spawn_3d(streams.get(sound), pos, vol_db, pitch)


func make_player_3d(sound: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = streams.get(sound)
	p.bus = "SFX"
	p.unit_size = 4.0
	p.max_distance = 30.0
	return p


# ---------- real recordings (BBC Sound Effects archive + Kenney) ----------

func _ogg(name: String) -> AudioStream:
	var path := "res://assets/sfx2/%s.ogg" % name
	return load(path) if ResourceLoader.exists(path) else null


## Several takes of one sound: each play picks one at random, with a little pitch wobble.
func _variants(names: Array, wobble := 1.06) -> AudioStream:
	var r := AudioStreamRandomizer.new()
	r.random_pitch = wobble
	for n in names:
		var st := _ogg(n)
		if st:
			r.add_stream(-1, st)
	return r if r.streams_count > 0 else null


func _load_real() -> void:
	var real := {
		"fart": _variants(["fart1", "fart2", "fart3"], 1.12),
		"kiss": _variants(["kiss"]),
		"giggle": _variants(["giggle1", "giggle2", "giggle3"]),
		"boo": _ogg("boo"),
		"honk": _variants(["honk", "honk2"]),
		"boing": _variants(["boing", "boing2"]),
		"bedcreak": _variants(["bedcreak"], 1.15),
		"partyhorn": _variants(["partywhistle"]),
		"pop": _ogg("cork"),
		"slip": _ogg("swanee"),
		"lights": _ogg("lightswitch"),
		"whoosh": _variants(["whoosh"], 1.1),
		"catch": _ogg("jingle_catch"),
		"gasp": _ogg("gasp"),
		"miss": _variants(["twang", "vibraslap"]),
		"win": _ogg("jingle_win"),
		"lose": _ogg("jingle_lose"),
		"hidestart": _ogg("jingle_hide"),
		"cheer": _ogg("cheer"),
		"laugh": _variants(["audiencelaugh", "horselaugh"]),
		"door": _ogg("creak"),
		"splat": _ogg("splat"),
		"burp": _ogg("burp"),
		"doorbell": _ogg("doorbell"),
		"fw_launch": _variants(["fw_launch", "fw_rocket"], 1.1),
		"fw_bang": _variants(["fw_bang"], 1.15),
		"meow": _variants(["meow1", "meow2"], 1.08),
		"woof": _variants(["woof1", "woof2"], 1.08),
		"shutter": _ogg("shutter"),
		"sizzle": _ogg("sizzle"),
	}
	for k in real:
		if real[k] != null:
			streams[k] = real[k]


## Announcer: "3", "2", "1", "go", "hurry_up", "time_over", "you_win", "you_lose"...
func say(word: String, vol_db := -2.0) -> void:
	var path := "res://assets/voice/%s.ogg" % word
	if not ResourceLoader.exists(path):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = load(path)
	p.volume_db = vol_db
	p.pitch_scale = 1.0
	p.play()


# ---------- ambience: birds when you are out in the garden ----------

var _amb_out: AudioStreamPlayer
var outdoors := 0.0  # 0 = inside, 1 = outside (main sets the target every frame)
var amb_on := false
var night := false  # chill mode: crickets instead of birds, faintly heard indoors too
var _amb_mix := 0.0
var _day_amb: AudioStream
var _night_amb: AudioStream


func _setup_ambience() -> void:
	_amb_out = AudioStreamPlayer.new()
	_day_amb = _ogg("amb_garden")
	_night_amb = _ogg("amb_night")
	for st in [_day_amb, _night_amb]:
		if st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = true
	_amb_out.stream = _day_amb
	_amb_out.bus = "SFX"
	_amb_out.volume_db = -80.0
	add_child(_amb_out)


func _process(dt: float) -> void:
	if _amb_out == null or _amb_out.stream == null:
		return
	var want: AudioStream = _night_amb if night else _day_amb
	if _amb_out.stream != want and want != null:
		_amb_out.stream = want
		_amb_out.stop()
	var goal := (outdoors if not night else lerpf(0.35, 1.0, outdoors)) if amb_on else 0.0
	_amb_mix = move_toward(_amb_mix, goal, dt * 0.8)
	if _amb_mix > 0.01:
		if not _amb_out.playing:
			_amb_out.play(randf() * 10.0)
		_amb_out.volume_db = -9.0 + linear_to_db(_amb_mix)
	elif _amb_out.playing:
		_amb_out.stop()


# ---------- synthesis ----------

func _begin(dur: float) -> void:
	_b = PackedFloat32Array()
	_b.resize(int(dur * RATE))
	_b.fill(0.0)


func _end(loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(_b.size() * 2)
	for i in _b.size():
		data.encode_s16(i * 2, int(clampf(_b[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = _b.size()
	return w


func _tone(start: float, dur: float, f0: float, f1: float, vol: float, wave := "sine", vib := 0.0) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	var ph := 0.0
	for i in n:
		if i0 + i >= _b.size():
			break
		var t := float(i) / RATE
		var k := t / dur
		var f := lerpf(f0, f1, k) + sin(t * 38.0) * vib
		ph += TAU * f / RATE
		var s := 0.0
		match wave:
			"sine":
				s = sin(ph)
			"square":
				s = 1.0 if sin(ph) >= 0.0 else -1.0
			"saw":
				s = fmod(ph / TAU, 1.0) * 2.0 - 1.0
			"tri":
				s = absf(fmod(ph / TAU, 1.0) * 4.0 - 2.0) - 1.0
		var env := minf(1.0, t / 0.008) * minf(1.0, (dur - t) / 0.04)
		_b[i0 + i] += s * vol * env


func _noise(start: float, dur: float, vol: float, lp: float, decay: float) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	var y := 0.0
	for i in n:
		if i0 + i >= _b.size():
			break
		var t := float(i) / RATE
		y += (randf() * 2.0 - 1.0 - y) * lp
		var env := exp(-t * decay) * minf(1.0, (dur - t) / 0.01)
		_b[i0 + i] += y * vol * env


## Engine rev: idle, blip up, settle back down. Sawtooth plus its octave and some grit.
func _engine(dur: float, idle: float, peak: float, vol: float) -> AudioStreamWAV:
	_begin(dur)
	var ph := 0.0
	var y := 0.0
	for i in _b.size():
		var t := float(i) / RATE
		var k := t / dur
		var curve := sin(clampf(k * 1.6, 0.0, 1.0) * PI) if k < 0.62 else 0.35 * (1.0 - (k - 0.62) / 0.38)
		var f := idle + (peak - idle) * maxf(curve, 0.0) + sin(t * 70.0) * 3.0
		ph += TAU * f / RATE
		var saw := fmod(ph / TAU, 1.0) * 2.0 - 1.0
		var oct := fmod(ph * 2.0 / TAU, 1.0) * 2.0 - 1.0
		y += ((randf() * 2.0 - 1.0) - y) * 0.3
		var env := minf(1.0, t / 0.05) * minf(1.0, (dur - t) / 0.3)
		_b[i] = (saw * 0.6 + oct * 0.25 + y * 0.25) * vol * env
	return _end()


func _build() -> void:
	_begin(0.08); _noise(0, 0.08, 0.9, 0.18, 45.0); streams["step"] = _end()

	_begin(0.62)
	for k in 5:
		_tone(k * 0.115, 0.085, 900.0 + k * 70.0, 1350.0 + k * 90.0, 0.3, "tri", 40.0)
	streams["giggle"] = _end()

	_begin(0.6); _tone(0, 0.22, 980, 1120, 0.35, "sine", 20); _tone(0.27, 0.3, 860, 760, 0.35, "sine", 20); streams["polo"] = _end()
	_begin(0.6); _tone(0, 0.22, 560, 660, 0.3, "tri"); _tone(0.27, 0.3, 880, 800, 0.3, "tri"); streams["marco"] = _end()

	_begin(0.75); _tone(0, 0.5, 1500, 260, 0.3, "sine"); _noise(0.5, 0.14, 0.7, 0.1, 25.0); _tone(0.5, 0.15, 140, 70, 0.5, "sine"); streams["slip"] = _end()

	_begin(0.9)
	var ph := 0.0
	for i in _b.size():
		var t := float(i) / RATE
		var f := 62.0 + 22.0 * sin(t * 29.0) + 10.0 * sin(t * 71.0) - t * 20.0
		ph += TAU * f / RATE
		var env := minf(1.0, t / 0.02) * minf(1.0, (0.9 - t) / 0.15)
		_b[i] = (fmod(ph / TAU, 1.0) * 2.0 - 1.0) * 0.45 * env + (randf() * 2.0 - 1.0) * 0.12 * env
	streams["fart"] = _end()

	_begin(0.55)
	var notes := [523.0, 659.0, 784.0, 1046.0]
	for k in 4:
		_tone(k * 0.1, 0.14 if k < 3 else 0.25, notes[k], notes[k], 0.18, "square")
	streams["catch"] = _end()

	_begin(0.3); _tone(0, 0.28, 170, 110, 0.3, "saw"); streams["miss"] = _end()
	_begin(0.14); _tone(0, 0.12, 880, 880, 0.3); streams["beep"] = _end()
	_begin(0.45); _tone(0, 0.4, 660, 660, 0.25); _tone(0, 0.4, 1320, 1320, 0.2); streams["go"] = _end()
	_begin(0.3); _tone(0, 0.28, 170, 640, 0.4, "sine", 30); streams["boing"] = _end()
	_begin(0.06); _noise(0, 0.06, 0.8, 0.5, 60.0); streams["pop"] = _end()
	_begin(0.25); _noise(0, 0.2, 0.9, 0.05, 18.0); _tone(0, 0.18, 110, 70, 0.4); streams["door"] = _end()
	_begin(0.32); _tone(0, 0.11, 58, 50, 0.8); _tone(0.17, 0.1, 54, 46, 0.55); streams["heart"] = _end()
	_begin(1.0); _noise(0, 1.0, 0.25, 0.7, 0.0); streams["tv"] = _end(true)
	_begin(0.35); _tone(0, 0.3, 240, 60, 0.25, "square"); streams["lights"] = _end()
	_begin(0.2); _noise(0, 0.04, 0.6, 0.6, 30.0); _tone(0.03, 0.14, 1500, 2300, 0.2); streams["kiss"] = _end()
	_begin(0.5); _tone(0, 0.12, 784, 784, 0.2, "tri"); _tone(0.13, 0.3, 1175, 1175, 0.2, "tri"); streams["win"] = _end()
	# BOO! a low growl that jumps up into a shriek
	_begin(0.9); _tone(0, 0.35, 90, 140, 0.5, "saw", 20); _tone(0.3, 0.55, 700, 1400, 0.35, "saw", 60); _noise(0.3, 0.5, 0.4, 0.5, 4.0); streams["boo"] = _end()
	_begin(0.45); _tone(0, 0.18, 900, 500, 0.35, "tri", 30); _tone(0.17, 0.25, 600, 350, 0.3, "tri", 30); streams["ouch"] = _end()
	_begin(0.7); _tone(0, 0.22, 1400, 2100, 0.25, "sine"); _tone(0.3, 0.38, 2100, 1300, 0.25, "sine"); streams["whistle"] = _end()
	_begin(0.35)
	for k in 3:
		_tone(k * 0.1, 0.08, 1800, 2600, 0.22, "sine", 80)
	streams["squeak"] = _end()
	_begin(0.5); _tone(0, 0.08, 520, 520, 0.25, "tri"); _tone(0.1, 0.08, 660, 660, 0.25, "tri"); _tone(0.2, 0.25, 880, 820, 0.25, "tri"); streams["peekaboo"] = _end()
	_begin(0.3); _noise(0, 0.25, 0.6, 0.35, 12.0); streams["poof"] = _end()
	_begin(0.6); _noise(0, 0.5, 0.25, 0.15, 3.0); _tone(0, 0.5, 300, 900, 0.08, "sine"); streams["sniff"] = _end()
	# a soft wish twinkle: little rising bells
	_begin(1.4)
	var bells := [1318.5, 1568.0, 1975.5, 2637.0, 3136.0]
	for k in bells.size():
		_tone(k * 0.09, 1.1 - k * 0.12, bells[k], bells[k], 0.09, "sine", 6.0)
	streams["twinkle"] = _end()
