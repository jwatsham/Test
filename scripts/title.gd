extends Node2D
## Title screen: Dr. Crunch demo-cracks random patients to a looping groove.

const DEMO_X := 960.0
const BELT_Y := 560.0

var _music: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _crack: AudioStream
var _spb := 0.5
var _last_beat := -1
var _bg: Background
var _chiro: Chiropractor
var _patient: Patient
var _title: Label
var _offset_label: Label
var _t := 0.0


func _ready() -> void:
	_bg = Background.new()
	add_child(_bg)
	_chiro = Chiropractor.new()
	_chiro.position = Vector2(DEMO_X, BELT_Y)
	add_child(_chiro)

	var song := Synth.build_song(108.0, PackedStringArray(["b", "b", "c", "c"]), true)
	_spb = song["spb"]
	_music = AudioStreamPlayer.new()
	_music.stream = song["stream"]
	_music.volume_db = -4.0
	add_child(_music)
	_music.play()
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	_crack = Synth.crack_sfx()

	var ui := CanvasLayer.new()
	add_child(ui)
	_title = UI.label("RHYTHM\nCHIROPRACTOR", 84, Color("#ffe135"), 18)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size = _title.get_minimum_size()
	_title.pivot_offset = _title.size * 0.5
	_title.position = Vector2(380 - _title.size.x * 0.5, 190)
	ui.add_child(_title)
	var tag := UI.label("Crack backs. On beat. Professionally.*", 24, Color.WHITE, 8)
	tag.position = Vector2(380 - tag.get_minimum_size().x * 0.5, 420)
	ui.add_child(tag)
	var fine := UI.label("*not a real doctor", 14, Color("#fff6d5"), 5)
	fine.position = Vector2(380 - fine.get_minimum_size().x * 0.5, 456)
	ui.add_child(fine)
	var start := UI.label("PRESS SPACE / CLICK TO START", 30, Color("#7ee081"))
	start.position = Vector2(380 - start.get_minimum_size().x * 0.5, 500)
	ui.add_child(start)
	var tw := start.create_tween().set_loops()
	tw.tween_property(start, "modulate:a", 0.35, 0.5)
	tw.tween_property(start, "modulate:a", 1.0, 0.5)
	var how := UI.label("Crack each patient's back when they reach the glowing zone.\nTwo-crack patients need a quick CRACK-CRACK!", 18, Color.WHITE, 6)
	how.position = Vector2(24, 630)
	ui.add_child(how)
	_offset_label = UI.label("", 16, Color("#fff6d5"), 5)
	_offset_label.position = Vector2(24, 20)
	ui.add_child(_offset_label)
	var best := UI.label("Best score: %d" % Settings.best_score, 18, Color.WHITE, 6)
	best.position = Vector2(24, 44)
	ui.add_child(best)
	_update_offset_label()
	_new_patient()


func _new_patient() -> void:
	if _patient:
		_patient.queue_free()
	_patient = Patient.new()
	_patient.setup(Patient.ROSTER.pick_random())
	_patient.position = Vector2(DEMO_X, BELT_Y - 260)
	add_child(_patient)
	_patient.create_tween().tween_property(_patient, "position:y", BELT_Y, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	var t := _music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	var beat_f := t / _spb
	var beat := int(floor(beat_f)) % 16
	var phase := fposmod(beat_f, 1.0)
	if beat != _last_beat and beat >= 0:
		_last_beat = beat
		if beat % 2 == 0:
			_chiro.slam(_patient.body_width(), _patient.grab_height())
			_patient.adjust(0.0)
			_patient.celebrate()
			_sfx.stream = _crack
			_sfx.pitch_scale = randf_range(0.9, 1.2)
			_sfx.play()
		else:
			_new_patient()
	_chiro.beat_phase = phase
	_patient.beat_phase = phase
	_bg.pulse = pow(1.0 - phase, 3.0)
	_bg.scroll += delta * 40.0
	_bg.queue_redraw()
	_title.rotation = sin(_t * 2.0) * 0.04
	_title.scale = Vector2.ONE * (1.0 + 0.04 * pow(1.0 - phase, 3.0))


func _update_offset_label() -> void:
	_offset_label.text = "Audio offset: %+d ms   ( [ / ] to adjust, if you're always early/late )   F11: fullscreen" % Settings.audio_offset_ms


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var k := (event as InputEventKey).keycode
		if k == KEY_BRACKETLEFT or k == KEY_BRACKETRIGHT:
			Settings.audio_offset_ms += 5 if k == KEY_BRACKETRIGHT else -5
			Settings.save()
			_update_offset_label()
			return
	if event.is_action_pressed("crack") and not event.is_echo():
		get_tree().change_scene_to_file("res://scenes/game.tscn")
	elif event.is_action_pressed("ui_cancel"):
		get_tree().quit()
