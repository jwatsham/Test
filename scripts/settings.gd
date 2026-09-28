extends Node
## Autoload "Settings": persisted player settings and best score.
## Also handles global hotkeys (F11 / Alt+Enter = fullscreen).

const PATH := "user://settings.cfg"

## Positive = the game assumes you hear the audio later. Raise it if you are
## consistently judged LATE, lower it if consistently EARLY.
var audio_offset_ms := 0
var best_score := 0


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		audio_offset_ms = int(cfg.get_value("audio", "offset_ms", 0))
		best_score = int(cfg.get_value("progress", "best_score", 0))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "offset_ms", audio_offset_ms)
	cfg.set_value("progress", "best_score", best_score)
	cfg.save(PATH)


## Returns true if this is a new best.
func submit_score(score: int) -> bool:
	if score > best_score:
		best_score = score
		save()
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
			var win := get_window()
			win.mode = Window.MODE_WINDOWED if win.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
			get_viewport().set_input_as_handled()
