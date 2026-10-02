class_name Debris
extends Node2D
## Anything floating in the pool. Arrives by flying in on an arc (thrown over
## the fence or blown off the tree), splashes down, then drifts around.

enum State { FLYING, FLOATING }

const OUTLINE := Layout.OUTLINE

## name: popup text when scooped. tips: $ earned. gross: Gross-o-meter weight.
## weight: how often it spawns. Add new junk here and give it a case in _draw.
const KINDS := {
	"leaf":    {"name": "Leaf", "radius": 11.0, "tips": 1, "gross": 0.5, "weight": 10.0},
	"sock":    {"name": "Soggy Sock", "radius": 13.0, "tips": 3, "gross": 3.0, "weight": 2.0},
	"duck":    {"name": "Rubber Duck", "radius": 13.0, "tips": 2, "gross": 0.5, "weight": 2.0},
	"pizza":   {"name": "Pool Pizza", "radius": 15.0, "tips": 4, "gross": 4.0, "weight": 1.5},
	"toupee":  {"name": "Someone's Toupee", "radius": 15.0, "tips": 6, "gross": 3.0, "weight": 1.0},
	"phone":   {"name": "A Phone?!", "radius": 12.0, "tips": 8, "gross": 1.0, "weight": 0.8},
	"ball":    {"name": "Beach Ball", "radius": 21.0, "tips": 3, "gross": 0.5, "weight": 1.2},
	"bandaid": {"name": "Mystery Band-Aid", "radius": 10.0, "tips": 5, "gross": 6.0, "weight": 0.8},
	"frog":    {"name": "FROG RESCUED!", "radius": 13.0, "tips": 10, "gross": 0.0, "weight": 0.0},
	"dale":    {"name": "Uncle Dale", "radius": 50.0, "tips": 0, "gross": 0.0, "weight": 0.0},
}

var kind := "leaf"
var info: Dictionary
var radius := 11.0
var state := State.FLOATING
var vel := Vector2.ZERO
var spin := 0.0
var tint := Color.WHITE

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _fly_t := 0.0
var _fly_dur := 1.0
var _t := 0.0
var _hop_cd := 1.0
var _grumpy := 0.0

signal landed(debris: Debris)


func setup(k: String) -> void:
	kind = k
	info = KINDS[k]
	radius = info["radius"]
	rotation = randf() * TAU
	spin = randf_range(-0.6, 0.6)
	_t = randf() * 10.0
	tint = [Color("#5aa83a"), Color("#e8892c"), Color("#d9b330"), Color("#a3502b")].pick_random()


## Launch from `from` and land at `to` (inside the pool) after `dur` seconds.
func throw(from: Vector2, to: Vector2, dur := 1.0) -> void:
	state = State.FLYING
	_from = from
	_to = to
	_fly_dur = dur
	_fly_t = 0.0
	position = from


func catchable() -> bool:
	return state == State.FLOATING and kind != "dale"


## Uncle Dale got poked.
func grumble() -> void:
	_grumpy = 1.0
	spin = 4.0


func _process(delta: float) -> void:
	_t += delta
	_grumpy = move_toward(_grumpy, 0.0, delta)
	if state == State.FLYING:
		_fly_t += delta
		var k := minf(_fly_t / _fly_dur, 1.0)
		position = _from.lerp(_to, k)
		rotation += spin * delta * 6.0
		if k >= 1.0:
			state = State.FLOATING
			vel = (_to - _from).normalized() * 30.0
			landed.emit(self)
	else:
		if kind == "frog":
			_hop_cd -= delta
			if _hop_cd <= 0.0:
				_hop_cd = randf_range(0.8, 1.8)
				vel += Vector2.from_angle(randf() * TAU) * 120.0
		rotation += spin * delta
		spin = lerpf(spin, signf(spin) * 0.3, delta)
	queue_redraw()


## Physics step called by the game (keeps all pool rules in one place).
func drift(delta: float, wind: Vector2) -> void:
	if state != State.FLOATING:
		return
	var mass := 4.0 if kind == "dale" else 1.0
	# Pool filter current: a slow clockwise swirl.
	var c := Layout.POOL.get_center()
	var off := (position - c) / Layout.POOL.size
	var swirl := Vector2(-off.y, off.x).normalized() * 6.0
	vel += (swirl + wind / mass) * delta
	vel *= exp(-0.6 * delta)
	position += vel * delta
	var inner := Layout.POOL.grow(-radius)
	if position.x < inner.position.x or position.x > inner.end.x:
		vel.x = -vel.x * 0.6
	if position.y < inner.position.y or position.y > inner.end.y:
		vel.y = -vel.y * 0.6
	position = position.clamp(inner.position, inner.end)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	draw_set_transform_matrix(Transform2D(0.0, r, 0.0, c))
	draw_circle(Vector2.ZERO, 1.0, col)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw() -> void:
	var height := 0.0
	if state == State.FLYING:
		var k := minf(_fly_t / _fly_dur, 1.0)
		height = sin(k * PI) * 120.0
		# Shadow stays on the ground/water while the item is in the air.
		var shadow_offset := Vector2(0, height).rotated(-rotation)
		draw_set_transform(shadow_offset, 0.0, Vector2.ONE)
		draw_circle(Vector2.ZERO, radius * 0.9, Color(0, 0, 0, 0.18))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		scale = Vector2.ONE * (1.0 + height / 200.0)
	else:
		scale = Vector2.ONE * (1.0 + sin(_t * 3.0) * 0.03)
		# Little water ring around floating things.
		draw_arc(Vector2.ZERO, radius + 5.0 + sin(_t * 2.0) * 2.0, 0, TAU, 24, Color(1, 1, 1, 0.25), 2.0)

	match kind:
		"leaf":
			var pts := PackedVector2Array()
			for i in 12:
				var a := float(i) / 12.0 * TAU
				var r := radius * (1.0 - 0.45 * absf(sin(a)))
				pts.append(Vector2(cos(a) * r * 1.2, sin(a) * r * 0.75))
			draw_colored_polygon(pts, tint)
			draw_polyline(pts + PackedVector2Array([pts[0]]), OUTLINE, 2.0)
			draw_line(Vector2(-radius * 1.3, 0), Vector2(radius * 1.1, 0), tint.darkened(0.4), 2.0)
		"sock":
			draw_line(Vector2(-4, -12), Vector2(-4, 6), OUTLINE, 14.0)
			draw_line(Vector2(-4, 6), Vector2(8, 8), OUTLINE, 14.0)
			draw_line(Vector2(-4, -12), Vector2(-4, 6), Color("#f2f2f2"), 9.0)
			draw_line(Vector2(-4, 6), Vector2(8, 8), Color("#f2f2f2"), 9.0)
			draw_line(Vector2(-9, -10), Vector2(1, -10), Color("#e63946"), 3.0)
			draw_line(Vector2(-9, -6), Vector2(1, -6), Color("#3a86ff"), 3.0)
		"duck":
			_ellipse(Vector2(0, 2), Vector2(14, 11), OUTLINE)
			_ellipse(Vector2(0, 2), Vector2(11.5, 8.5), Color("#ffd23f"))
			draw_circle(Vector2(6, -6), 8.5, OUTLINE)
			draw_circle(Vector2(6, -6), 6.5, Color("#ffd23f"))
			draw_colored_polygon(PackedVector2Array([Vector2(11, -7), Vector2(18, -5), Vector2(11, -3)]), Color("#ff8c1a"))
			draw_circle(Vector2(7, -8), 1.6, OUTLINE)
		"pizza":
			var tri := PackedVector2Array([Vector2(-15, -10), Vector2(15, -10), Vector2(0, 16)])
			draw_colored_polygon(tri, OUTLINE)
			draw_colored_polygon(PackedVector2Array([Vector2(-11, -8), Vector2(11, -8), Vector2(0, 11)]), Color("#ffd166"))
			draw_line(Vector2(-14, -10), Vector2(14, -10), Color("#c98b3b"), 5.0)
			for p: Vector2 in [Vector2(-4, -3), Vector2(4, -2), Vector2(0, 4)]:
				draw_circle(p, 2.8, Color("#c0392b"))
		"toupee":
			_ellipse(Vector2.ZERO, Vector2(17, 11), OUTLINE)
			_ellipse(Vector2.ZERO, Vector2(14, 8.5), Color("#5b3a1e"))
			for i in 5:
				var x := -10.0 + i * 5.0
				draw_line(Vector2(x, -6), Vector2(x + 3, 6), Color("#3d2512"), 2.0)
		"phone":
			draw_rect(Rect2(-8, -13, 16, 26), OUTLINE)
			draw_rect(Rect2(-6, -11, 12, 20), Color("#3a86ff").lerp(Color.WHITE, 0.3 + 0.2 * sin(_t * 5.0)))
			draw_circle(Vector2(0, 11), 1.5, Color("#888"))
		"ball":
			draw_circle(Vector2.ZERO, radius + 3.0, OUTLINE)
			var cols := [Color("#e63946"), Color.WHITE, Color("#3a86ff"), Color.WHITE, Color("#ffd23f"), Color.WHITE]
			for i in 6:
				var a0 := float(i) / 6.0 * TAU
				var seg := PackedVector2Array([Vector2.ZERO])
				for k in 5:
					seg.append(Vector2.from_angle(a0 + k / 4.0 * TAU / 6.0) * radius)
				draw_colored_polygon(seg, cols[i])
			draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
		"bandaid":
			draw_rect(Rect2(-12, -5, 24, 10), OUTLINE)
			draw_rect(Rect2(-10, -3.5, 20, 7), Color("#e8b48a"))
			draw_rect(Rect2(-4, -3.5, 8, 7), Color("#c9956a"))
			draw_circle(Vector2(0, 0), 1.5, Color("#7a8b2a"))
		"frog":
			for s: float in [-1.0, 1.0]:
				_ellipse(Vector2(s * 9, 7), Vector2(6, 4), OUTLINE)
				_ellipse(Vector2(s * 9, 7), Vector2(4.5, 3), Color("#4c9e2f"))
			_ellipse(Vector2.ZERO, Vector2(12, 11), OUTLINE)
			_ellipse(Vector2.ZERO, Vector2(10, 9), Color("#6cc24a"))
			for s: float in [-1.0, 1.0]:
				draw_circle(Vector2(s * 5, -8), 4.5, OUTLINE)
				draw_circle(Vector2(s * 5, -8), 3.5, Color.WHITE)
				draw_circle(Vector2(s * 5, -9), 1.6, OUTLINE)
		"dale":
			_draw_dale()


func _draw_dale() -> void:
	# A pink flamingo floatie (top-down ring) with a sunburnt uncle asleep in it.
	draw_circle(Vector2.ZERO, 50.0, OUTLINE)
	draw_circle(Vector2.ZERO, 46.0, Color("#ff7eb6"))
	draw_circle(Vector2.ZERO, 26.0, OUTLINE)
	draw_circle(Vector2.ZERO, 23.0, Color("#3fc1e0"))
	# Flamingo neck and head.
	draw_line(Vector2(0, -44), Vector2(10, -66), OUTLINE, 14.0)
	draw_line(Vector2(0, -44), Vector2(10, -66), Color("#ff7eb6"), 9.0)
	draw_circle(Vector2(12, -70), 10.0, OUTLINE)
	draw_circle(Vector2(12, -70), 7.5, Color("#ff7eb6"))
	draw_colored_polygon(PackedVector2Array([Vector2(18, -72), Vector2(28, -66), Vector2(18, -66)]), OUTLINE)
	# Uncle Dale: belly, arms flopped over the ring, head with tiny sunglasses.
	draw_circle(Vector2(0, 4), 22.0, OUTLINE)
	draw_circle(Vector2(0, 4), 19.0, Color("#f08a6b"))
	for s: float in [-1.0, 1.0]:
		draw_line(Vector2(s * 14, -4), Vector2(s * 40, -12), OUTLINE, 11.0)
		draw_line(Vector2(s * 14, -4), Vector2(s * 40, -12), Color("#f08a6b"), 7.0)
	draw_circle(Vector2(0, -20), 13.0, OUTLINE)
	draw_circle(Vector2(0, -20), 10.5, Color("#f08a6b"))
	draw_line(Vector2(-7, -22), Vector2(7, -22), OUTLINE, 4.0)
	draw_rect(Rect2(-18, 14, 36, 10), Color("#2a9d8f"))  # trunks
	# Snore Zs (or angry lines when poked).
	var font := ThemeDB.fallback_font
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	if _grumpy > 0.0:
		draw_string_outline(font, Vector2(-26, -40), "HEY!!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, OUTLINE)
		draw_string(font, Vector2(-26, -40), "HEY!!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#ff5a5a"))
	else:
		for i in 3:
			var ph := fmod(_t * 0.6 + i / 3.0, 1.0)
			var p := Vector2(20 + ph * 30, -30 - ph * 40)
			var col := Color(1, 1, 1, 1.0 - ph)
			draw_string(font, p, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 + ph * 12), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
