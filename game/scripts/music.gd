extends Node
## Background music with crossfades. Each mood has a playlist, so rounds don't all sound the same.
## Game tracks by Kevin MacLeod (incompetech.com), CC BY 4.0.

const M := "res://assets/music/"
const POOLS := {
	"menu": ["Monkeys_Spinning_Monkeys", "Carefree", "Local_Forecast_Elevator", "Wallpaper"],
	"hide": ["Fluffing_a_Duck", "Pixel_Peeker_Polka_faster", "Merry_Go", "Kool_Kats", "Bushwick_Tarantella"],
	"seek": ["Sneaky_Snitch", "Sneaky_Adventure", "Hidden_Agenda", "Spy_Glass", "Scheming_Weasel_slower"],
	"chase": ["Run_Amok", "Scheming_Weasel_faster", "Hustle"],
	"results": ["Investigations", "The_Builder"],
}
const CREDITS := "PekaBoo v1.0 · made with 💜 by RubinBastakoti.\n\nMusic by Kevin MacLeod (incompetech.com), CC BY 4.0: Monkeys Spinning Monkeys, Carefree, Local Forecast, Wallpaper, Fluffing a Duck, Pixel Peeker Polka, Merry Go, Kool Kats, Bushwick Tarantella, Sneaky Snitch, Sneaky Adventure, Hidden Agenda, Spy Glass, Scheming Weasel, Run Amok, Hustle, Investigations, The Builder.\nSound effects from the BBC Sound Effects archive (personal use). Furniture, characters, jingles, voice & sounds by Kenney (kenney.nl, CC0). Textures, sky & props from Poly Haven (CC0). Peeking-face emoji from Twemoji (CC BY 4.0). Font: Fredoka (SIL OFL)."

var current := ""        # mood
var enabled := true      # the on/off switch in Settings (and in chill mode's Together panel)
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _positions := {}  # file -> where it was, so seek <-> chase flips resume instead of restarting
var _pick := {}       # mood -> the file chosen for this round
var _file := ""
signal song_ended
var songs: Array[String] = []  # chill mode playlist (res://assets/songs), same order on both phones
var _song_i := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
		p.finished.connect(_on_finished.bind(p))
	var d := DirAccess.open("res://assets/songs")
	if d:
		for f in d.get_files():
			f = f.trim_suffix(".import").trim_suffix(".remap")
			if f.ends_with(".ogg") and not songs.has(f) and ResourceLoader.exists("res://assets/songs/" + f):
				songs.append(f)
	songs.sort()


## New round: choose fresh tracks for every mood.
func new_round() -> void:
	_pick.clear()


func _file_for(mood: String) -> String:
	if not _pick.has(mood):
		var pool: Array = POOLS[mood]
		_pick[mood] = M + str(pool[randi() % pool.size()]) + ".mp3"
	return _pick[mood]


## Chill mode: play song i (both phones are told the same i, so they hear the same thing).
func play_song(i: int, fade := 1.2) -> void:
	if songs.is_empty():
		# a build without the love songs: soft game music instead
		play("menu", fade)
		return
	current = "songs"
	_song_i = posmod(i, songs.size())
	_switch("res://assets/songs/" + songs[_song_i], fade)


func song_index() -> int:
	return _song_i if current == "songs" else -1


func now_playing() -> String:
	if current != "songs" or _song_i < 0:
		return ""
	return songs[_song_i].get_basename().replace("_", " ")


func _on_finished(p: AudioStreamPlayer) -> void:
	if p == _players[_active] and current == "songs":
		song_ended.emit()


## Make the song swell for a moment (kiss!).
func swell(extra_db := 4.0, secs := 4.0) -> void:
	var p := _players[_active]
	var base := p.volume_db
	var tw := create_tween()
	tw.tween_property(p, "volume_db", base + extra_db, 0.8)
	tw.tween_interval(secs)
	tw.tween_property(p, "volume_db", base, 1.5)


func play(mood: String, fade := 1.2) -> void:
	if mood == current or not POOLS.has(mood):
		return
	current = mood
	_switch(_file_for(mood), fade)


func _switch(file: String, fade: float) -> void:
	var old := _players[_active]
	if _file != "":
		_positions[_file] = old.get_playback_position()
	_file = file
	_active = 1 - _active
	var p := _players[_active]
	var s: AudioStream = load(file)
	var is_song := file.begins_with("res://assets/songs/")
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = not is_song
	p.stream = s
	p.volume_db = -40.0
	p.play(0.0 if is_song else _positions.get(file, 0.0))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(p, "volume_db", -3.0 if is_song else -6.0, fade)
	tw.tween_property(old, "volume_db", -60.0, fade)
	tw.chain().tween_callback(old.stop)


## Replay: everything a little slower and deeper.
func slowmo(on: bool) -> void:
	for p in _players:
		p.pitch_scale = 0.8 if on else 1.0


func stop(fade := 1.0) -> void:
	current = ""
	for p in _players:
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -60.0, fade)
		tw.tween_callback(p.stop)
