class_name Save
extends RefCounted
## Tiny persistent store for the best score.

const PATH := "user://save.cfg"


static func best_tips() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return 0
	return int(cfg.get_value("progress", "best_tips", 0))


## Returns true if `tips` is a new best.
static func submit(tips: int) -> bool:
	if tips <= best_tips():
		return false
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("progress", "best_tips", tips)
	cfg.save(PATH)
	return true
