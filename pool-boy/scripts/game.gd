extends Node2D
## One shift as the Pool Boy. Everything is built in code so game.tscn is a single node.
##
## Loop: walk the deck, hold the net button to reach into the pool, scoop junk,
## dump a full net in the trash can. Don't let the Gross-o-meter max out, and
## don't poke Uncle Dale while he naps.

const SHIFT_LENGTH := 120.0
const SPEED := 330.0
const PLAYER_R := 20.0
const MAX_REACH := 250.0       ## How far past the rim the net head can go.
const EXTEND_RATE := 2.6       ## Net extend speed (fraction of full reach per second).
const RETRACT_RATE := 4.5
const CAPACITY := 5
const GROSS_MAX := 35.0        ## Gross-o-meter limit.
const GROSS_GRACE := 4.0       ## Seconds at max before you're fired.
const DUMP_RADIUS := 60.0
const FULL_NET_BONUS := 5
const DALE_PENALTY := 5

const IDLE_REMARKS := [
	"Don't forget the deep end, sweetie!",
	"I pay you in exposure, you know.",
	"Love the shorts. Very... brave.",
	"My husband built this pool himself.",
	"That net is older than you are.",
	"Are you skimming or swimming?",
	"Hustle! The book club arrives at 4!",
]
const RANKS := [
	[150, "Pool Legend", "\"Marry me. Or at least come back Tuesday.\""],
	[100, "Employee of the Month", "\"Sparkling! Have a lemonade.\""],
	[60, "Adequate Pool Boy", "\"It's... wet. That's something.\""],
	[30, "Pool Disappointment", "\"I found a sock in my lemonade.\""],
	[0, "Please Return the Net", "\"Who even hired you?\""],
]
const KIND_COLORS := {
	"leaf": Color("#5aa83a"), "sock": Color("#f2f2f2"), "duck": Color("#ffd23f"),
	"pizza": Color("#ffd166"), "toupee": Color("#5b3a1e"), "phone": Color("#3a86ff"),
	"ball": Color("#e63946"), "bandaid": Color("#e8b48a"),
}

var tips := 0
var scooped := 0
var frogs := 0
var naps_ruined := 0

var _yard: Yard
var _top: Yard
var _items: Node2D
var _boy: PoolBoy
var _ui: CanvasLayer
var _tips_label: Label
var _time_label: Label
var _gross_fill: ColorRect
var _gross_label: Label
var _hint: Label

var _music: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _snd := {}

var _pos := Vector2(640, 612)
var _extend := 0.0
var _contents: Array[String] = []
var _stun := 0.0
var _time := 0.0
var _spawn_cd := 1.5
var _gust_cd := 16.0
var _gust_time := 0.0
var _gust_dir := Vector2.RIGHT
var _gust_leaves := 0
var _wind := Vector2.ZERO
var _frog_cd := 22.0
var _dale_spawned := false
var _kid_time := 0.0
var _remark_cd := 5.0
var _gross_over := 0.0
var _finished := false
var _finished_at := 0.0
## Debug: `-- --autoplay` lets a bot play; `--report` prints the result.
var _autoplay := OS.get_cmdline_user_args().has("--autoplay")


func _ready() -> void:
	randomize()
	_yard = Yard.new()
	add_child(_yard)
	_items = Node2D.new()
	add_child(_items)
	_boy = PoolBoy.new()
	_boy.capacity = CAPACITY
	add_child(_boy)
	_top = Yard.new()
	_top.canopy = true
	add_child(_top)
	_build_ui()
	_build_audio()
	for i in 4:
		var d := _make("leaf")
		d.position = Vector2(randf_range(Layout.POOL.position.x + 40, Layout.POOL.end.x - 40), randf_range(Layout.POOL.position.y + 40, Layout.POOL.end.y - 40))
	_say("Pool's filthy, hon. Get skimming!", 3.5)


# --- Setup ---

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_tips_label = UI.label("", 30, Color("#7ee081"))
	_tips_label.position = Vector2(16, 2)
	_ui.add_child(_tips_label)
	_time_label = UI.label("", 32)
	_time_label.position = Vector2(600, 0)
	_ui.add_child(_time_label)
	_gross_label = UI.label("GROSS-O-METER", 16, Color.WHITE, 6)
	_gross_label.position = Vector2(1000, 2)
	_ui.add_child(_gross_label)
	var bg := ColorRect.new()
	bg.color = Layout.OUTLINE
	bg.position = Vector2(1000, 24)
	bg.size = Vector2(264, 16)
	_ui.add_child(bg)
	_gross_fill = ColorRect.new()
	_gross_fill.position = Vector2(1002, 26)
	_gross_fill.size = Vector2(0, 12)
	_ui.add_child(_gross_fill)
	_hint = UI.label("WASD / Arrows: walk     Hold SPACE: reach with the net     Full net? Dump it in the TRASH", 20, Color.WHITE, 7)
	_hint.position = Vector2(640 - _hint.get_minimum_size().x * 0.5, 676)
	_ui.add_child(_hint)


func _build_audio() -> void:
	_music = AudioStreamPlayer.new()
	_music.stream = Synth.music_loop()
	_music.volume_db = -6.0
	add_child(_music)
	_music.play()
	_snd = {"scoop": Synth.scoop(), "splash": Synth.splash(), "dump": Synth.dump(), "hey": Synth.hey(),
		"ribbit": Synth.ribbit(), "whistle": Synth.whistle(), "womp": Synth.womp(), "gust": Synth.gust()}
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)


func _play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	var p := _sfx_players[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx_players.size()
	p.stream = _snd[name]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func _make(kind: String) -> Debris:
	var d := Debris.new()
	d.setup(kind)
	d.landed.connect(_on_landed)
	_items.add_child(d)
	return d


func _say(text: String, seconds := 3.0) -> void:
	_top.bubble_text = text
	_top.bubble_time = seconds
	_remark_cd = randf_range(9.0, 14.0)


func _random_pool_point(margin := 40.0) -> Vector2:
	var r := Layout.POOL.grow(-margin)
	return Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))


# --- Frame loop ---

func _process(delta: float) -> void:
	if _finished:
		return
	_time += delta
	_update_player(delta)
	_update_spawns(delta)
	_update_wind(delta)
	for child in _items.get_children():
		(child as Debris).drift(delta, _wind)
	_update_net()
	_update_gross(delta)
	_update_hud()
	_remark_cd -= delta
	if _remark_cd <= 0.0:
		_say(IDLE_REMARKS.pick_random())
	if _time >= SHIFT_LENGTH:
		_finish(false)


func _update_player(delta: float) -> void:
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var reaching := Input.is_action_pressed("net")
	if _autoplay:
		var bot := _bot()
		move = bot[0]
		reaching = bot[1]
	if _stun > 0.0:
		_stun -= delta
		move = Vector2.ZERO
		reaching = false
	var speed := SPEED * (0.5 if _extend > 0.2 else 1.0)
	_pos += move * speed * delta
	_pos = _pos.clamp(Layout.DECK.position + Vector2.ONE * PLAYER_R, Layout.DECK.end - Vector2.ONE * PLAYER_R)
	# Keep feet on the deck: push out of the pool to the nearest side.
	var keep := Layout.POOL.grow(PLAYER_R + 4.0)
	if keep.has_point(_pos):
		var d_left := _pos.x - keep.position.x
		var d_right := keep.end.x - _pos.x
		var d_top := _pos.y - keep.position.y
		var d_bottom := keep.end.y - _pos.y
		var m := minf(minf(d_left, d_right), minf(d_top, d_bottom))
		if m == d_left:
			_pos.x = keep.position.x
		elif m == d_right:
			_pos.x = keep.end.x
		elif m == d_top:
			_pos.y = keep.position.y
		else:
			_pos.y = keep.end.y
	var rate := EXTEND_RATE if reaching else RETRACT_RATE
	_extend = move_toward(_extend, 1.0 if reaching else 0.0, rate * delta)

	var dir := Layout.into_pool(_pos)
	_boy.position = _pos
	_boy.dir = _boy.dir.slerp(dir, minf(delta * 14.0, 1.0)).normalized()
	_boy.head = Layout.pool_point(_pos) + _boy.dir * _net_reach()
	_boy.moving = move.length() > 0.1
	_boy.stunned = _stun
	_boy.contents.clear()
	for k in _contents:
		_boy.contents.append(KIND_COLORS.get(k, Color.WHITE))

	# Dump at the trash can.
	if not _contents.is_empty() and _pos.distance_to(Layout.BIN) < DUMP_RADIUS:
		var full := _contents.size() >= CAPACITY
		_contents.clear()
		_play("dump", randf_range(0.9, 1.1))
		UI.popup(_ui, "DUMPED!", Layout.BIN + Vector2(60, -40), 30, Color.WHITE)
		if full:
			tips += FULL_NET_BONUS
			UI.popup(_ui, "FULL NET +$%d" % FULL_NET_BONUS, Layout.BIN + Vector2(90, -80), 24, Color("#7ee081"))
	_yard.bin_glow = 1.0 if _contents.size() >= CAPACITY else 0.0
	var under_tree := _pos.distance_to(Layout.TREE) < 200.0
	_top.canopy_alpha = move_toward(_top.canopy_alpha, 0.35 if under_tree else 1.0, delta * 4.0)


func _update_spawns(delta: float) -> void:
	_spawn_cd -= delta
	if _spawn_cd <= 0.0:
		var k := _time / SHIFT_LENGTH
		_spawn_cd = lerpf(3.0, 1.3, k) * randf_range(0.7, 1.3)
		if randf() < 0.5:
			_spawn_leaf()
		else:
			_spawn_junk()
	_frog_cd -= delta
	if _frog_cd <= 0.0:
		_frog_cd = randf_range(18.0, 28.0)
		var f := _make("frog")
		f.throw(Vector2(randf_range(300, 1000), 712), _random_pool_point(60.0), 0.9)
		_play("ribbit")
		_say("Is that a FROG?! Get it out!", 2.5)
	if not _dale_spawned and _time > 14.0:
		_dale_spawned = true
		var dale := _make("dale")
		dale.throw(Vector2(Layout.POOL.position.x + 120, Layout.POOL.end.y + 40), Layout.POOL.get_center() + Vector2(-120, 30), 1.2)
		_say("Dale! Don't splash the help!", 3.5)
	_kid_time = maxf(_kid_time - delta, 0.0)
	if _kid_time == 0.0:
		_yard.kid_x = -1.0


func _spawn_leaf() -> void:
	var d := _make("leaf")
	var to := Layout.POOL.position + Vector2(randf_range(20, 380), randf_range(20, 280))
	if _wind.length() > 20.0:
		to = _random_pool_point(30.0)
	d.throw(Layout.TREE + Vector2(randf_range(-40, 60), randf_range(-30, 50)), to, 1.5)


func _spawn_junk() -> void:
	var total := 0.0
	for k: String in Debris.KINDS:
		if k != "leaf":
			total += float(Debris.KINDS[k]["weight"])
	var roll := randf() * total
	var kind := "sock"
	for k: String in Debris.KINDS:
		if k == "leaf":
			continue
		roll -= float(Debris.KINDS[k]["weight"])
		if roll <= 0.0:
			kind = k
			break
	var x := randf_range(320, 960)
	_yard.kid_x = x
	_kid_time = 0.9
	var d := _make(kind)
	d.throw(Vector2(x, 34), _random_pool_point(30.0), 0.9)


func _update_wind(delta: float) -> void:
	_gust_cd -= delta
	if _gust_cd <= 0.0 and _gust_time <= 0.0:
		_gust_cd = randf_range(14.0, 22.0)
		_gust_time = 3.0
		_gust_dir = Vector2(1.0 if randf() < 0.5 else -1.0, randf_range(-0.3, 0.3)).normalized()
		_gust_leaves = 5
		_play("gust", 1.0, -2.0)
		_say("Ooh, it's getting WINDY!", 2.0)
	if _gust_time > 0.0:
		_gust_time -= delta
		var env := sin(clampf(_gust_time / 3.0, 0.0, 1.0) * PI)
		_wind = _gust_dir * 70.0 * env
		if _gust_leaves > 0 and randf() < delta * 3.0:
			_gust_leaves -= 1
			_spawn_leaf()
	else:
		_wind = Vector2.ZERO
	_top.wind = _wind


func _update_net() -> void:
	var head := _boy.head
	if _extend <= 0.001 or not Layout.POOL.has_point(head):
		return
	for child in _items.get_children():
		var d := child as Debris
		if d.state != Debris.State.FLOATING or d.is_queued_for_deletion():
			continue
		var reach := PoolBoy.NET_RADIUS + d.radius * (0.8 if d.kind == "dale" else 0.6)
		if head.distance_to(d.position) > reach:
			continue
		if d.kind == "dale":
			if _stun <= 0.0:
				_poke_dale(d)
			return
		if d.kind == "frog":
			_rescue_frog(d)
		elif _contents.size() < CAPACITY:
			_scoop(d)


func _scoop(d: Debris) -> void:
	var t: int = d.info["tips"]
	tips += t
	scooped += 1
	_contents.append(d.kind)
	_play("scoop", randf_range(0.85, 1.3))
	_yard.ripple(d.position)
	UI.popup(_ui, "+$%d %s" % [t, d.info["name"]], d.position + Vector2(0, -30), 22, Color("#7ee081"))
	match d.kind:
		"toupee":
			_say("Is that... GARY'S toupee?!")
		"phone":
			_say("My PHONE! I've been looking for that!")
		"bandaid":
			_say("Don't tell me where that came from.")
	d.queue_free()


func _rescue_frog(d: Debris) -> void:
	tips += int(d.info["tips"])
	frogs += 1
	_play("ribbit", 1.2)
	UI.popup(_ui, "FROG RESCUED! +$%d" % int(d.info["tips"]), d.position + Vector2(0, -30), 26, Color("#ffd23f"))
	d.set_meta("leaving", true)
	d.throw(d.position, Vector2(randf_range(80, 1200), 700), 0.8)


func _poke_dale(d: Debris) -> void:
	naps_ruined += 1
	tips = maxi(tips - DALE_PENALTY, 0)
	_stun = 0.7
	_extend = 0.0
	d.grumble()
	d.vel += (d.position - _pos).normalized() * 60.0
	_play("hey")
	_play("splash", 0.8, -4.0)
	UI.popup(_ui, "-$%d DON'T POKE DALE" % DALE_PENALTY, d.position + Vector2(0, -70), 24, Color("#ff5a5a"))
	_say("Leave Dale alone, he's on VACATION!")


func _on_landed(d: Debris) -> void:
	if d.has_meta("leaving"):
		d.queue_free()
		return
	_yard.ripple(d.position)
	_play("splash", randf_range(0.8, 1.3) * (0.7 if d.kind == "dale" else 1.0), -6.0 if d.kind == "leaf" else 0.0)


func _gross() -> float:
	var g := 0.0
	for child in _items.get_children():
		var d := child as Debris
		if d.state == Debris.State.FLOATING and not d.is_queued_for_deletion():
			g += float(d.info["gross"])
	return g


func _update_gross(delta: float) -> void:
	var g := _gross()
	if g >= GROSS_MAX:
		if _gross_over == 0.0:
			_say("This pool is DISGUSTING! Fix it NOW!", GROSS_GRACE)
		_gross_over += delta
		if _gross_over >= GROSS_GRACE:
			_finish(true)
	else:
		_gross_over = maxf(_gross_over - delta * 2.0, 0.0)


func _update_hud() -> void:
	_tips_label.text = "TIPS $%d" % tips
	var left := maxf(SHIFT_LENGTH - _time, 0.0)
	_time_label.text = "%d:%02d" % [int(left) / 60, int(left) % 60]
	var k := clampf(_gross() / GROSS_MAX, 0.0, 1.0)
	_gross_fill.size.x = 260.0 * k
	_gross_fill.color = Color("#7ee081").lerp(Color("#ffd23f"), clampf(k * 2.0, 0.0, 1.0)).lerp(Color("#ff3b3b"), clampf(k * 2.0 - 1.0, 0.0, 1.0))
	if _gross_over > 0.0 and fmod(_time, 0.3) < 0.15:
		_gross_fill.color = Color.WHITE
	_hint.modulate.a = clampf(14.0 - _time, 0.0, 1.0)


## Distance from the rim to the net head. At rest the net hovers just over the water.
func _net_reach() -> float:
	return 26.0 + _extend * (MAX_REACH - 26.0)


# --- Autoplay bot (for testing) ---

## Returns [move_vector, reaching].
func _bot() -> Array:
	if _contents.size() >= CAPACITY:
		return [(Layout.BIN - _pos).normalized(), false]
	var best: Debris = null
	var best_d := INF
	for child in _items.get_children():
		var d := child as Debris
		if not d.catchable() or d.is_queued_for_deletion():
			continue
		var dist := _pos.distance_to(_stand_for(d.position))
		if dist < best_d:
			best_d = dist
			best = d
	if best == null:
		return [Vector2.ZERO, false]
	var stand := _stand_for(best.position)
	if _pos.distance_to(stand) > 14.0:
		return [(stand - _pos).normalized(), false]
	var need := Layout.pool_point(_pos).distance_to(best.position)
	return [Vector2.ZERO, _net_reach() < need + 8.0 or _extend < 0.1]


## Where to stand on the deck to reach `p` most directly.
func _stand_for(p: Vector2) -> Vector2:
	var pool := Layout.POOL
	var off := PLAYER_R + 4.0
	var sides := [p.x - pool.position.x, pool.end.x - p.x, p.y - pool.position.y, pool.end.y - p.y]
	var i := sides.find(sides.min())
	match i:
		0: return Vector2(pool.position.x - off, p.y)
		1: return Vector2(pool.end.x + off, p.y)
		2: return Vector2(p.x, pool.position.y - off)
	return Vector2(p.x, pool.end.y + off)


# --- Input & results ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/title.tscn")
	elif _finished and event.is_action_pressed("net") and Time.get_ticks_msec() / 1000.0 - _finished_at > 1.0:
		get_tree().reload_current_scene()


func _finish(fired: bool) -> void:
	if _finished:
		return
	_finished = true
	_finished_at = Time.get_ticks_msec() / 1000.0
	_extend = 0.0
	_play("womp" if fired else "whistle")
	_music.volume_db = -14.0
	var rank: Array = RANKS[RANKS.size() - 1]
	for r in RANKS:
		if tips >= int(r[0]):
			rank = r
			break
	var title := "SHIFT OVER!"
	var rank_name: String = rank[1]
	var quote: String = rank[2]
	if fired:
		title = "YOU'RE FIRED!"
		rank_name = "Terminated for Gross Negligence"
		quote = "\"I've seen cleaner swamps.\""
	var new_best := false if _autoplay else Save.submit(tips)
	if OS.get_cmdline_user_args().has("--report"):
		print("RESULT fired=%s tips=%d scooped=%d frogs=%d naps_ruined=%d time=%.1f" % [fired, tips, scooped, frogs, naps_ruined, _time])

	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(panel)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.12, 0.2, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(dim)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var lines := [
		[title, 64, Color("#ff5a5a") if fired else Color.WHITE],
		["$%d in tips" % tips, 72, Color("#7ee081")],
		[rank_name, 36, Color("#ffd23f")],
		["NEW BEST!" if new_best else "Best: $%d" % Save.best_tips(), 24, Color.WHITE],
		["Junk scooped: %d     Frogs rescued: %d     Naps ruined: %d" % [scooped, frogs, naps_ruined], 24, Color.WHITE],
		["Mrs. Henderson says: " + quote, 24, Color("#fff6d5")],
		["SPACE: next shift      ESC: title", 24, Color("#9ad1ff")],
	]
	for line in lines:
		var l := UI.label(line[0], line[1], line[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.4)
