extends Node2D
## Title screen: the backyard on a lazy day, with Dale drifting and the
## Pool Boy idly skimming.

var _boy: PoolBoy
var _t := 0.0


func _ready() -> void:
	var yard := Yard.new()
	add_child(yard)
	var items := Node2D.new()
	add_child(items)
	for k: String in ["leaf", "leaf", "duck", "ball", "sock", "dale"]:
		var d := Debris.new()
		d.setup(k)
		d.position = Vector2(randf_range(320, 960), randf_range(240, 500))
		d.vel = Vector2.from_angle(randf() * TAU) * 20.0
		items.add_child(d)
	_boy = PoolBoy.new()
	add_child(_boy)
	var top := Yard.new()
	top.canopy = true
	top.bubble_text = "Pool's not gonna skim itself!"
	top.bubble_time = 9999.0
	add_child(top)

	var music := AudioStreamPlayer.new()
	music.stream = Synth.music_loop()
	music.volume_db = -6.0
	add_child(music)
	music.play()

	var ui := CanvasLayer.new()
	add_child(ui)
	var title := UI.label("POOL BOY", 132, Color("#ffd23f"), 24)
	title.position = Vector2(640 - title.get_minimum_size().x * 0.5, 150)
	title.pivot_offset = title.get_minimum_size() * 0.5
	ui.add_child(title)
	var tw := title.create_tween().set_loops()
	tw.tween_property(title, "rotation", 0.03, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "rotation", -0.03, 1.2).set_trans(Tween.TRANS_SINE)
	var tag := UI.label("Skim the pool. Dodge Uncle Dale. Survive Mrs. Henderson.", 28, Color.WHITE, 8)
	tag.position = Vector2(640 - tag.get_minimum_size().x * 0.5, 330)
	ui.add_child(tag)
	var start := UI.label("PRESS SPACE / CLICK TO START", 34, Color("#7ee081"))
	start.position = Vector2(640 - start.get_minimum_size().x * 0.5, 400)
	ui.add_child(start)
	var blink := start.create_tween().set_loops()
	blink.tween_property(start, "modulate:a", 0.35, 0.5)
	blink.tween_property(start, "modulate:a", 1.0, 0.5)
	var how := UI.label("WASD / Arrows: walk     Hold SPACE: reach with the net     Full net? Dump it in the TRASH", 20, Color.WHITE, 7)
	how.position = Vector2(640 - how.get_minimum_size().x * 0.5, 676)
	ui.add_child(how)
	var best := UI.label("Best shift: $%d" % Save.best_tips(), 20, Color.WHITE, 6)
	best.position = Vector2(16, 6)
	ui.add_child(best)
	_items_ref = items


var _items_ref: Node2D


func _process(delta: float) -> void:
	_t += delta
	for child in _items_ref.get_children():
		(child as Debris).drift(delta, Vector2.ZERO)
	# The Pool Boy strolls along the bottom deck, idly poking the net out.
	var p := Vector2(640 + sin(_t * 0.4) * 300.0, Layout.POOL.end.y + 24.0)
	_boy.moving = absf(cos(_t * 0.4)) > 0.2
	_boy.position = p
	_boy.dir = Layout.into_pool(p)
	_boy.head = Layout.pool_point(p) + _boy.dir * (40.0 + 60.0 * (0.5 + 0.5 * sin(_t * 1.7)))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("net"):
		get_tree().change_scene_to_file("res://scenes/game.tscn")
	elif event.is_action_pressed("ui_cancel"):
		get_tree().quit()
