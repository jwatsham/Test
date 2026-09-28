class_name Patient
extends Node2D
## A customer riding the conveyor belt. Drawn entirely in code: a squishy tube
## body that follows a bent "spine" curve, plus a head style and a face.
## `bend` = 1 means fully crooked, 0 means perfectly straight.
## The origin is at the patient's feet, on top of the belt. They face left.

enum Mood { WORRIED, HAPPY, HURT }

const OUTLINE := Color(0.12, 0.1, 0.16)

## The patient roster. "hits" = how many cracks it takes to fix them.
## Add a new patient by adding a dictionary here (and a head style in _draw_head
## if you want a new look). "shape" is one of: C, S, arc, zig, wave.
static var ROSTER: Array[Dictionary] = [
	{"name": "Gary from Accounting", "head": "human", "hair": "short", "hair_color": Color("#5b3a1e"),
		"skin": Color("#f1c27d"), "body": Color("#4a78c2"), "legs_color": Color("#2f2f3a"),
		"height": 130.0, "width": 46.0, "legs": 34.0, "shape": "C", "amp": 38.0, "arms": true, "hits": 1},
	{"name": "Grandma Edna", "head": "human", "hair": "bun", "hair_color": Color("#d8d8e0"), "glasses": true,
		"skin": Color("#f5d0b0"), "body": Color("#e58fb5"), "legs_color": Color("#6d5a7a"),
		"height": 115.0, "width": 44.0, "legs": 28.0, "shape": "C", "amp": 52.0, "arms": true, "hits": 1},
	{"name": "Sir Barks-a-Lot", "head": "dog",
		"skin": Color("#b7793f"), "body": Color("#b7793f"), "legs_color": Color("#8a5a2b"),
		"height": 95.0, "width": 48.0, "legs": 26.0, "shape": "S", "amp": 30.0, "arms": true, "hits": 1},
	{"name": "Mr. Whiskers", "head": "cat",
		"skin": Color("#f29b38"), "body": Color("#f29b38"), "legs_color": Color("#d9822b"),
		"height": 90.0, "width": 42.0, "legs": 22.0, "shape": "S", "amp": 34.0, "arms": true, "hits": 1},
	{"name": "A Banana", "head": "banana",
		"skin": Color("#ffe135"), "body": Color("#ffe135"),
		"height": 150.0, "width": 42.0, "legs": 0.0, "shape": "arc", "amp": 60.0, "taper": 0.5, "hits": 1},
	{"name": "Robo-Bob 3000", "head": "robot",
		"skin": Color("#a9b4c2"), "body": Color("#a9b4c2"), "legs_color": Color("#6b7686"),
		"height": 120.0, "width": 48.0, "legs": 30.0, "shape": "zig", "amp": 26.0, "arms": true, "hits": 1},
	# Two-crack patients.
	{"name": "Gerald the Giraffe", "head": "giraffe",
		"skin": Color("#f2c14e"), "body": Color("#f2c14e"), "legs_color": Color("#d9a531"),
		"height": 220.0, "width": 38.0, "legs": 40.0, "shape": "S", "amp": 44.0, "taper": 0.5, "spots": true, "hits": 2},
	{"name": "Noodle the Snake", "head": "snake",
		"skin": Color("#6cc24a"), "body": Color("#6cc24a"),
		"height": 170.0, "width": 30.0, "legs": 0.0, "shape": "wave", "amp": 34.0, "coil": true, "hits": 2},
	{"name": "A Desk Lamp", "head": "lamp",
		"skin": Color("#e04f5f"), "body": Color("#8d99ae"),
		"height": 160.0, "width": 16.0, "legs": 0.0, "shape": "zig", "amp": 40.0, "base": true, "hits": 2},
]

var data: Dictionary
var anchor_beat := 0.0
var bend := 1.0
var bend_target := 1.0
var bend_vel := 0.0
var mood := Mood.WORRIED
var beat_phase := 0.0  ## 0..1 position inside the current beat, for idle bobbing.
var show_name := true

var _start_bend := 1.0
var _hop := 0.0
var _hop_vel := 0.0
var _squash := 0.0
var _wobble := 0.0
var _t := 0.0


func setup(d: Dictionary, anchor := 0.0) -> void:
	data = d
	anchor_beat = anchor
	_start_bend = randf_range(0.85, 1.15)
	bend = _start_bend
	bend_target = bend
	_t = randf() * 10.0


## Called on a successful crack. `remaining` is the fraction of crookedness left.
func adjust(remaining: float) -> void:
	bend_target = _start_bend * remaining
	bend_vel -= 16.0
	_squash = 0.35


func celebrate() -> void:
	mood = Mood.HAPPY
	_hop_vel = 560.0


func botch() -> void:
	mood = Mood.HURT
	bend_target = 1.6
	bend_vel += 10.0
	_wobble = 1.0


func body_width() -> float:
	return float(data.get("width", 40.0))


## Height above the feet where the chiropractor's hands should land.
func grab_height() -> float:
	return float(data.get("legs", 0.0)) + float(data.get("height", 100.0)) * 0.45


func _process(delta: float) -> void:
	_t += delta
	# Underdamped spring so spines snap straight with a satisfying wobble.
	bend_vel += (bend_target - bend) * 260.0 * delta
	bend_vel *= exp(-9.0 * delta)
	bend += bend_vel * delta
	if _hop > 0.0 or _hop_vel > 0.0:
		_hop_vel -= 1800.0 * delta
		_hop = maxf(_hop + _hop_vel * delta, 0.0)
		if _hop == 0.0:
			_hop_vel = 0.0
	_squash = move_toward(_squash, 0.0, delta * 2.0)
	_wobble = move_toward(_wobble, 0.0, delta * 1.2)
	queue_redraw()


func _shape(t: float) -> float:
	match data.get("shape", "C"):
		"C":
			return sin(t * PI) * 0.8 - t * t * 0.6  # hunched: back bulges, head juts forward
		"S":
			return sin(t * TAU) * 0.8
		"arc":
			return sin(t * PI)
		"zig":
			return asin(sin(t * 3.0 * PI)) / (PI * 0.5) * 0.7
		"wave":
			return sin(t * 4.0 * PI) * 0.6
	return 0.0


func _ellipse(xf: Transform2D, center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform_matrix(xf * Transform2D(0.0, radii, 0.0, center))
	draw_circle(Vector2.ZERO, 1.0, color)


func _draw() -> void:
	if data.is_empty():
		return
	var h: float = data["height"]
	var w: float = data["width"]
	var legs: float = data.get("legs", 0.0)
	var taper: float = data.get("taper", 0.0)
	var body_col: Color = data["body"]
	var skin: Color = data["skin"]

	# Shadow stays on the belt while the patient hops.
	_ellipse(Transform2D.IDENTITY, Vector2(0, 2), Vector2(w * 0.8 + 10.0, 7.0), Color(0, 0, 0, 0.25))

	var bob := pow(1.0 - beat_phase, 3.0) * 0.05
	var sx := 1.0 + _squash * 0.5 + bob
	var sy := 1.0 - _squash * 0.4 - bob
	var shake := sin(_t * 60.0) * 7.0 * _wobble
	var base := Transform2D(0.0, Vector2(sx, sy), 0.0, Vector2(shake, -_hop))
	draw_set_transform_matrix(base)

	# Spine curve, from the hips up to the neck.
	var n := maxi(int(h / 6.0), 10)
	var pts := PackedVector2Array()
	var radii := PackedFloat32Array()
	for i in n + 1:
		var t := float(i) / n
		pts.append(Vector2(bend * float(data["amp"]) * _shape(t), -legs - t * h))
		radii.append(w * 0.5 * (1.0 - taper * t))

	# Legs / base.
	if legs > 0.0:
		var leg_col: Color = data.get("legs_color", body_col)
		for side: float in [-1.0, 1.0]:
			var hip := Vector2(side * w * 0.22, -legs - 4.0)
			var foot := Vector2(side * w * 0.22 + sin(_t * 9.0 + side) * 2.0, 0.0)
			draw_line(hip, foot, OUTLINE, 15.0)
			draw_line(hip, foot, leg_col, 9.0)
			_ellipse(base, foot + Vector2(-5, -3), Vector2(10, 6), OUTLINE)
			draw_set_transform_matrix(base)
	if data.get("base", false):
		_ellipse(base, Vector2(0, -6), Vector2(36, 11), OUTLINE)
		_ellipse(base, Vector2(0, -7), Vector2(32, 8), Color("#4a4e69"))
		draw_set_transform_matrix(base)
	if data.get("coil", false):
		_ellipse(base, Vector2(6, -12), Vector2(42, 15), OUTLINE)
		_ellipse(base, Vector2(6, -13), Vector2(38, 11), body_col.darkened(0.15))
		draw_set_transform_matrix(base)

	# Body tube: outline pass then fill pass.
	for i in pts.size():
		draw_circle(pts[i], radii[i] + 3.5, OUTLINE)
	for i in pts.size():
		draw_circle(pts[i], radii[i], body_col)
	if data.get("spots", false):
		for i in range(2, pts.size() - 2, 4):
			draw_circle(pts[i] + Vector2(radii[i] * (0.35 if i % 8 == 2 else -0.3), 0), radii[i] * 0.35, Color("#a0522d"))

	# Vertebrae: angry red when crooked, calm white when straight.
	var vcol := Color("#ff4d4d").lerp(Color(1, 1, 1, 0.9), clampf(1.0 - absf(bend), 0.0, 1.0))
	for i in range(1, pts.size() - 1, 2):
		draw_circle(pts[i] + Vector2(radii[i] * 0.35, 0), maxf(radii[i] * 0.14, 2.5), vcol)

	# Dangly arms.
	if data.get("arms", false):
		var sh := pts[int(n * 0.72)]
		var swing := sin(_t * 7.0) * 4.0
		var hand := sh + Vector2(-22.0 + swing, 34.0)
		var arm_col: Color = body_col.darkened(0.1)
		draw_line(sh, hand, OUTLINE, 13.0)
		draw_line(sh, hand, arm_col, 8.0)
		draw_circle(hand, 7.0, OUTLINE)
		draw_circle(hand, 5.0, skin)

	# Head, rotated to follow the top of the spine.
	var top := pts[pts.size() - 1]
	var dir := (top - pts[pts.size() - 2]).normalized()
	var head_xf := base * Transform2D(dir.angle() + PI * 0.5, top)
	draw_set_transform_matrix(head_xf)
	_draw_head(head_xf, skin, body_col)

	# Name tag.
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if show_name:
		var font := ThemeDB.fallback_font
		var label: String = data["name"]
		var fs := 15
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(-tw * 0.5, -legs - h - 72.0 - _hop)
		draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, OUTLINE)
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _draw_head(xf: Transform2D, skin: Color, body_col: Color) -> void:
	match data.get("head", "human"):
		"human":
			var hair: Color = data.get("hair_color", Color.BLACK)
			if data.get("hair", "") == "bun":
				draw_circle(Vector2(12, -46), 15.0, OUTLINE)
				draw_circle(Vector2(12, -46), 12.0, hair)
			draw_circle(Vector2(2, -24), 27.0, OUTLINE)
			draw_circle(Vector2(2, -24), 24.0, hair)
			draw_circle(Vector2(-3, -18), 22.0, skin)
			draw_circle(Vector2(-25, -15), 7.0, OUTLINE)
			draw_circle(Vector2(-25, -15), 5.0, skin)
			_face(Vector2(-6, -18), 1.0)
			if data.get("glasses", false):
				draw_arc(Vector2(-15, -21), 7.5, 0, TAU, 16, OUTLINE, 2.0)
				draw_arc(Vector2(1, -21), 7.5, 0, TAU, 16, OUTLINE, 2.0)
		"dog":
			draw_circle(Vector2(0, -22), 27.0, OUTLINE)
			draw_circle(Vector2(0, -22), 24.0, skin)
			_ellipse(xf, Vector2(-20, -13), Vector2(18, 13), OUTLINE)
			_ellipse(xf, Vector2(-20, -13), Vector2(15, 10), skin.lightened(0.35))
			draw_set_transform_matrix(xf)
			draw_circle(Vector2(-34, -16), 6.0, OUTLINE)
			_ellipse(xf, Vector2(12, -18), Vector2(10, 20), OUTLINE)
			_ellipse(xf, Vector2(12, -18), Vector2(7, 17), skin.darkened(0.35))
			draw_set_transform_matrix(xf)
			_face(Vector2(-6, -30), 0.9)
		"cat":
			for ear in [[Vector2(-18, -36), Vector2(-10, -58), Vector2(-2, -42)], [Vector2(2, -42), Vector2(12, -58), Vector2(18, -34)]]:
				draw_colored_polygon(PackedVector2Array(ear), OUTLINE)
			draw_circle(Vector2(0, -22), 26.0, OUTLINE)
			draw_circle(Vector2(0, -22), 23.0, skin)
			draw_circle(Vector2(-14, -14), 3.5, Color("#ff8fab"))
			for k in 3:
				var y := -14.0 + (k - 1) * 4.0
				draw_line(Vector2(-18, y), Vector2(-40, y + (k - 1) * 4.0), OUTLINE, 1.5)
				draw_line(Vector2(10, y), Vector2(32, y + (k - 1) * 4.0), OUTLINE, 1.5)
			_face(Vector2(-4, -26), 0.9)
		"giraffe":
			for dx in [0.0, 10.0]:
				draw_line(Vector2(dx, -18), Vector2(dx + 2, -40), OUTLINE, 5.0)
				draw_circle(Vector2(dx + 2, -42), 5.0, Color("#6b3e1f"))
			_ellipse(xf, Vector2(-10, -14), Vector2(26, 17), OUTLINE)
			_ellipse(xf, Vector2(-10, -14), Vector2(23, 14), skin)
			draw_set_transform_matrix(xf)
			draw_circle(Vector2(-30, -12), 2.5, OUTLINE)
			_face(Vector2(-8, -18), 0.8)
		"banana":
			_ellipse(xf, Vector2(0, -4), Vector2(6, 10), Color("#4a3419"))
			draw_set_transform_matrix(xf)
			_face(Vector2(-4, 34), 0.9)
		"robot":
			var blink := Color("#ff3b3b") if fmod(_t, 1.0) < 0.5 else Color("#ffd166")
			draw_line(Vector2(0, -40), Vector2(0, -58), OUTLINE, 3.0)
			draw_circle(Vector2(0, -60), 6.0, blink)
			draw_rect(Rect2(-27, -45, 54, 46), OUTLINE)
			draw_rect(Rect2(-24, -42, 48, 40), skin)
			_face(Vector2(-4, -22), 1.0)
		"snake":
			var flick := 6.0 if fmod(_t * 3.0, 1.0) < 0.5 else 0.0
			draw_line(Vector2(-30, -8), Vector2(-40 - flick, -8), Color("#e63946"), 2.5)
			_ellipse(xf, Vector2(-10, -10), Vector2(25, 16), OUTLINE)
			_ellipse(xf, Vector2(-10, -10), Vector2(22, 13), skin)
			draw_set_transform_matrix(xf)
			_face(Vector2(-10, -14), 0.8)
		"lamp":
			var shade := PackedVector2Array([Vector2(-34, 4), Vector2(34, 4), Vector2(18, -36), Vector2(-18, -36)])
			draw_circle(Vector2(0, 8), 13.0, Color(1, 0.95, 0.5, 0.5))
			draw_circle(Vector2(0, 6), 8.0, Color("#fff3b0"))
			draw_colored_polygon(shade, OUTLINE)
			draw_colored_polygon(PackedVector2Array([Vector2(-29, 1), Vector2(29, 1), Vector2(15, -33), Vector2(-15, -33)]), skin)
			_face(Vector2(-2, -16), 0.8)
	draw_set_transform_matrix(xf)


func _face(c: Vector2, s: float) -> void:
	var e1 := c + Vector2(-9, -3) * s
	var e2 := c + Vector2(6, -3) * s
	match mood:
		Mood.HAPPY:
			draw_arc(e1, 5.0 * s, PI, TAU, 8, OUTLINE, 2.5 * s)
			draw_arc(e2, 5.0 * s, PI, TAU, 8, OUTLINE, 2.5 * s)
			draw_arc(c + Vector2(-2, 5) * s, 8.0 * s, 0.2, PI - 0.2, 12, OUTLINE, 3.0 * s)
		Mood.HURT:
			for e in [e1, e2]:
				draw_line(e + Vector2(-4, -4) * s, e + Vector2(4, 4) * s, OUTLINE, 2.5 * s)
				draw_line(e + Vector2(-4, 4) * s, e + Vector2(4, -4) * s, OUTLINE, 2.5 * s)
			draw_circle(c + Vector2(-2, 10) * s, 5.0 * s, Color("#7a1f2b"))
		_:
			for e in [e1, e2]:
				draw_circle(e, 5.0 * s, OUTLINE)
				draw_circle(e, 4.0 * s, Color.WHITE)
				draw_circle(e + Vector2(-1.5, 0.5) * s, 2.0 * s, OUTLINE)
			# Worried eyebrows and a wobbly mouth.
			draw_line(e1 + Vector2(-5, -9) * s, e1 + Vector2(4, -6) * s, OUTLINE, 2.0 * s)
			draw_line(e2 + Vector2(-4, -6) * s, e2 + Vector2(5, -9) * s, OUTLINE, 2.0 * s)
			var mouth := PackedVector2Array()
			for k in 5:
				mouth.append(c + Vector2(-8 + k * 3.5, 8 + (2.0 if k % 2 == 0 else -1.0)) * s)
			draw_polyline(mouth, OUTLINE, 2.0 * s)
