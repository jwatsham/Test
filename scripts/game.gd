extends Node2D
## Main gameplay. Everything is built from code so game.tscn stays a one-liner.
##
## Timing model: the song clock (seconds since beat 0) comes from the audio
## playback position, corrected for mix latency. Patients are positioned purely
## from that clock, so visuals can never drift from the music.

const HIT_X := 420.0
const BELT_Y := 560.0
const PIXELS_PER_BEAT := 230.0
const SPAWN_AHEAD_PX := 1100.0

# Timing windows in seconds, either side of the beat.
const WINDOW_PERFECT := 0.050
const WINDOW_GREAT := 0.100
const WINDOW_OK := 0.160

const POINTS := {"perfect": 300, "great": 200, "ok": 100}
const JUDGE_TEXT := {"perfect": "PERFECT CRACK!", "great": "NICE POP!", "ok": "EH, CLOSE ENOUGH", "miss": "OUCH!"}
const JUDGE_COLOR := {"perfect": Color("#ffd23f"), "great": Color("#7ee081"), "ok": Color("#9ad1ff"), "miss": Color("#ff5a5a")}
const CRACK_WORDS := ["CRACK!", "SNAP!", "POP!", "KRRK!", "CRUNCH!", "BLORP!"]

const RANKS := [
	[0.95, "S", "Board-Certified Spine Whisperer", "\"I can see my toes again!\" - Gary from Accounting"],
	[0.85, "A", "Chiropractor of the Month", "\"Hurt so good. 5 stars.\" - Sir Barks-a-Lot"],
	[0.70, "B", "Mostly Licensed", "\"I'm taller now? Maybe?\" - A Desk Lamp"],
	[0.50, "C", "Please Stop Touching People", "\"He folded me like a lawn chair.\" - Grandma Edna"],
	[0.00, "D", "Malpractice Suit Pending", "\"I am now a pretzel.\" - Noodle the Snake"],
]

var level: Dictionary
var spb := 0.5
var song_beats := 0.0

var _music: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _snd_crack: AudioStream
var _snd_womp: AudioStream
var _snd_whiff: AudioStream
var _snd_boing: AudioStream

var _world: Node2D
var _bg: Background
var _chiro: Chiropractor
var _zone: Node2D
var _patients_layer: Node2D

var _patients: Array[Dictionary] = []
var _notes: Array[Dictionary] = []
var _spawn_i := 0
var _first_open := 0

var score := 0
var combo := 0
var max_combo := 0
var fixed := 0
var counts := {"perfect": 0, "great": 0, "ok": 0, "miss": 0}

var _finished := false
var _finished_at := 0.0
var _last_time := -INF
var _beat := 0.0
var _shake := 0.0
## Debug: run with `-- --autoplay` and a bot hits every note perfectly.
## Add `--report` to print the results line to stdout.
var _autoplay := OS.get_cmdline_user_args().has("--autoplay")

var _ui: CanvasLayer
var _score_label: Label
var _combo_label: Label
var _fixed_label: Label
var _progress: ColorRect


func _ready() -> void:
	randomize()
	level = Levels.ALL[0]
	_build_world()
	_build_ui()
	_build_audio()
	_build_chart()
	_update_hud()
	_music.play()


# --- Setup ---

func _build_world() -> void:
	_world = Node2D.new()
	add_child(_world)
	_bg = Background.new()
	_world.add_child(_bg)
	_chiro = Chiropractor.new()
	_chiro.position = Vector2(HIT_X, BELT_Y)
	_world.add_child(_chiro)
	_zone = Node2D.new()
	_zone.draw.connect(_draw_zone)
	_world.add_child(_zone)
	_patients_layer = Node2D.new()
	_world.add_child(_patients_layer)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_score_label = UI.label("", 34)
	_score_label.position = Vector2(24, 14)
	_ui.add_child(_score_label)
	_fixed_label = UI.label("", 22, Color("#fff6d5"), 8)
	_fixed_label.position = Vector2(26, 60)
	_ui.add_child(_fixed_label)
	_combo_label = UI.label("", 40, Color("#ffd23f"))
	_combo_label.position = Vector2(700, 14)
	_combo_label.size = Vector2(556, 60)
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui.add_child(_combo_label)
	var title := UI.label(String(level["title"]), 20, Color.WHITE, 8)
	title.position = Vector2(640 - title.get_minimum_size().x * 0.5, 16)
	_ui.add_child(title)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.3)
	bar_bg.position = Vector2(440, 50)
	bar_bg.size = Vector2(400, 8)
	_ui.add_child(bar_bg)
	_progress = ColorRect.new()
	_progress.color = Color("#ffd23f")
	_progress.position = bar_bg.position
	_progress.size = Vector2(0, 8)
	_ui.add_child(_progress)
	var hint := UI.label("SPACE / CLICK on the beat!    ESC: quit", 18, Color.WHITE, 6)
	hint.position = Vector2(24, 686)
	_ui.add_child(hint)


func _build_audio() -> void:
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_music.finished.connect(_finish)
	var arrangement := String(level["arrangement"]).split(" ", false)
	song_beats = arrangement.size() * 4.0
	var music_path: String = level.get("music", "")
	if music_path != "":
		_music.stream = load(music_path)
		spb = 60.0 / float(level["bpm"])
	else:
		var song := Synth.build_song(float(level["bpm"]), arrangement)
		_music.stream = song["stream"]
		spb = song["spb"]
	_snd_crack = Synth.crack_sfx()
	_snd_womp = Synth.womp_sfx()
	_snd_whiff = Synth.whiff_sfx()
	_snd_boing = Synth.boing_sfx()
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)


func _build_chart() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1))
	var singles: Array[Dictionary] = []
	var doubles: Array[Dictionary] = []
	for d in Patient.ROSTER:
		if int(d["hits"]) == 1:
			singles.append(d)
		else:
			doubles.append(d)
	var intro := int(level["intro_bars"])
	var chart: Array = level["chart"]
	var last_type: Dictionary = {}
	for bar in chart.size():
		var row := String(chart[bar])
		for i in row.length():
			var beat := float((intro + bar) * 4 + i)
			var hits: Array[float] = []
			var pool: Array[Dictionary]
			if row[i] == "x":
				hits = [beat]
				pool = singles
			elif row[i] == "d":
				hits = [beat, beat + 0.5]
				pool = doubles
			else:
				continue
			var type: Dictionary = pool[rng.randi() % pool.size()]
			if type == last_type:
				type = pool[rng.randi() % pool.size()]
			last_type = type
			var p := {"type": type, "hits": hits, "anchor": (hits[0] + hits[-1]) * 0.5,
				"node": null, "done": 0, "missed": false}
			_patients.append(p)
			for h in hits:
				_notes.append({"time": h * spb, "patient": p, "judged": false})
	_notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] < b["time"])


# --- Clock ---

func _song_time() -> float:
	var t := _music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	t -= float(level.get("music_offset", 0.0)) + Settings.audio_offset_ms / 1000.0
	_last_time = maxf(_last_time, t)  # never run backwards
	return _last_time


# --- Frame loop ---

func _process(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, delta * 50.0)
	_world.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	if _finished:
		return
	var t := _song_time()
	_beat = t / spb
	var phase := fposmod(_beat, 1.0)

	if _autoplay and _first_open < _notes.size() and not _notes[_first_open]["judged"] \
			and t >= float(_notes[_first_open]["time"]):
		_crack()

	while _spawn_i < _patients.size():
		var p: Dictionary = _patients[_spawn_i]
		if (float(p["anchor"]) - _beat) * PIXELS_PER_BEAT > SPAWN_AHEAD_PX:
			break
		var pat := Patient.new()
		pat.setup(p["type"], p["anchor"])
		pat.position = Vector2(2000, BELT_Y)
		_patients_layer.add_child(pat)
		p["node"] = pat
		_spawn_i += 1

	for child in _patients_layer.get_children():
		var pat := child as Patient
		pat.position.x = HIT_X + (pat.anchor_beat - _beat) * PIXELS_PER_BEAT
		pat.beat_phase = phase
		pat.show_name = pat.position.x > HIT_X + 100.0
		if pat.position.x < -250.0:
			pat.queue_free()

	# Anything that scrolled past the window unhit is a miss.
	while _first_open < _notes.size():
		var n: Dictionary = _notes[_first_open]
		if n["judged"]:
			_first_open += 1
		elif t - float(n["time"]) > WINDOW_OK:
			_judge(n, INF)
			_first_open += 1
		else:
			break

	_bg.scroll = _beat * PIXELS_PER_BEAT
	_bg.pulse = pow(1.0 - phase, 3.0) if _beat >= 0.0 else 0.0
	_bg.queue_redraw()
	_chiro.beat_phase = phase
	_zone.queue_redraw()
	_progress.size.x = 400.0 * clampf(_beat / song_beats, 0.0, 1.0)

	if _beat >= song_beats:
		_finish()


func _draw_zone() -> void:
	var pulse := pow(1.0 - fposmod(_beat, 1.0), 3.0) if _beat >= 0.0 else 0.0
	var glow := Color(1.0, 0.55, 0.1)
	var half := 72.0 + 8.0 * pulse
	_zone.draw_rect(Rect2(HIT_X - half, BELT_Y - 320, half * 2.0, 320), Color(glow, 0.16 + 0.14 * pulse))
	# Chunky corner brackets so the zone reads even over Dr. Crunch's white coat.
	for side: float in [-1.0, 1.0]:
		var x := HIT_X + side * half
		for y: float in [BELT_Y - 320.0, BELT_Y]:
			var dy := 34.0 if y < BELT_Y else -34.0
			_zone.draw_line(Vector2(x, y), Vector2(x, y + dy), UI.OUTLINE, 11.0)
			_zone.draw_line(Vector2(x, y), Vector2(x - side * 26.0, y), UI.OUTLINE, 11.0)
			_zone.draw_line(Vector2(x, y), Vector2(x, y + dy), glow, 6.0)
			_zone.draw_line(Vector2(x, y), Vector2(x - side * 26.0, y), glow, 6.0)
	_zone.draw_set_transform(Vector2(HIT_X, BELT_Y + 6), 0.0, Vector2(half, 12.0))
	_zone.draw_circle(Vector2.ZERO, 1.0, Color(1.0, 0.8, 0.3, 0.45 + 0.4 * pulse))
	_zone.draw_set_transform(Vector2.ZERO)
	var tri := PackedVector2Array([Vector2(HIT_X - 20, BELT_Y + 62), Vector2(HIT_X + 20, BELT_Y + 62), Vector2(HIT_X, BELT_Y + 34)])
	_zone.draw_colored_polygon(tri, glow)
	_zone.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), UI.OUTLINE, 3.0)


# --- Input & judging ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/title.tscn")
		return
	if not event.is_action_pressed("crack") or event.is_echo():
		return
	if _finished:
		if Time.get_ticks_msec() / 1000.0 - _finished_at > 1.0:
			get_tree().reload_current_scene()
		return
	_crack()


func _crack() -> void:
	var t := _song_time()
	var target: Dictionary = {}
	for i in range(_first_open, _notes.size()):
		var n: Dictionary = _notes[i]
		var dt := t - float(n["time"])
		if dt < -WINDOW_OK:
			break
		if not n["judged"] and absf(dt) <= WINDOW_OK:
			target = n
			break
	if target.is_empty():
		_chiro.slam(20.0, 150.0)
		_play(_snd_whiff, randf_range(0.9, 1.15))
		return
	var pat: Patient = target["patient"]["node"]
	if pat:
		_chiro.slam(pat.body_width(), pat.grab_height())
	_judge(target, t - float(target["time"]))


func _judge(note: Dictionary, dt: float) -> void:
	note["judged"] = true
	var p: Dictionary = note["patient"]
	var pat: Patient = p["node"]
	var ad := absf(dt)
	var grade := "miss"
	if ad <= WINDOW_PERFECT:
		grade = "perfect"
	elif ad <= WINDOW_GREAT:
		grade = "great"
	elif ad <= WINDOW_OK:
		grade = "ok"
	counts[grade] += 1
	p["done"] = int(p["done"]) + 1
	var total_hits: int = p["hits"].size()

	var judge_pos := Vector2(HIT_X + 250, 250)
	if grade == "miss":
		combo = 0
		p["missed"] = true
		if pat:
			pat.botch()
		_chiro.sweat()
		_play(_snd_womp, randf_range(0.95, 1.05))
		UI.popup(_ui, JUDGE_TEXT[grade], judge_pos, 46, JUDGE_COLOR[grade])
	else:
		combo += 1
		max_combo = maxi(max_combo, combo)
		var mult := mini(1 + int(combo / 10.0), 4)
		score += int(POINTS[grade]) * mult
		if pat and not p["missed"]:
			pat.adjust(1.0 - float(p["done"]) / total_hits)
		_play(_snd_crack, randf_range(0.85, 1.25))
		UI.popup(_ui, JUDGE_TEXT[grade], judge_pos, 46 if grade == "perfect" else 38, JUDGE_COLOR[grade])
		if grade != "perfect":
			UI.popup(_ui, "early" if dt < 0.0 else "late", judge_pos + Vector2(0, 44), 22, Color.WHITE, 50.0)
		UI.popup(_ui, CRACK_WORDS.pick_random(), Vector2(HIT_X + randf_range(-60, 60), 330), 30, Color.WHITE, 90.0, 0.5)
		_shake = 10.0 if grade == "perfect" else 5.0

	if p["done"] == total_hits and not p["missed"]:
		fixed += 1
		if pat:
			pat.celebrate()
		_play(_snd_boing, randf_range(0.9, 1.2), -8.0)
	_update_hud()


func _play(stream: AudioStream, pitch := 1.0, volume_db := 0.0) -> void:
	var player := _sfx_players[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx_players.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()


func _update_hud() -> void:
	_score_label.text = "SCORE  %d" % score
	_fixed_label.text = "Spines fixed: %d / %d" % [fixed, _patients.size()]
	var mult := mini(1 + int(combo / 10.0), 4)
	_combo_label.text = ("COMBO %d" % combo) + ("  x%d" % mult if mult > 1 else "") if combo > 1 else ""


# --- Results ---

func _accuracy() -> float:
	if _notes.is_empty():
		return 0.0
	var pts: float = counts["perfect"] + counts["great"] * 0.7 + counts["ok"] * 0.4
	return pts / _notes.size()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_finished_at = Time.get_ticks_msec() / 1000.0
	var acc := _accuracy()
	var rank: Array = RANKS[RANKS.size() - 1]
	for r in RANKS:
		if acc >= float(r[0]):
			rank = r
			break
	var new_best := false if _autoplay else Settings.submit_score(score)
	if OS.get_cmdline_user_args().has("--report"):
		print("RESULT rank=%s score=%d acc=%.3f fixed=%d/%d counts=%s" % [rank[1], score, acc, fixed, _patients.size(), counts])

	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(panel)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.15, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(dim)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var lines := [
		["SHIFT OVER!", 48, Color.WHITE],
		[String(rank[1]), 120, Color("#ffd23f")],
		[String(rank[2]), 34, Color("#ffd6e0")],
		["Score: %d%s" % [score, "   NEW BEST!" if new_best else "   (best %d)" % Settings.best_score], 30, Color.WHITE],
		["Spines fixed: %d / %d     Max combo: %d     Accuracy: %d%%" % [fixed, _patients.size(), max_combo, int(acc * 100.0)], 24, Color.WHITE],
		["Perfect %d   Great %d   OK %d   Miss %d" % [counts["perfect"], counts["great"], counts["ok"], counts["miss"]], 22, Color("#9ad1ff")],
		["★ Review: " + String(rank[3]), 22, Color("#fff6d5")],
		["SPACE: another shift      ESC: title", 24, Color("#7ee081")],
	]
	for line in lines:
		var l := UI.label(line[0], line[1], line[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.4)
