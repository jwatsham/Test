class_name PoolBoy
extends Node2D
## The hero, seen from above: tank top, short shorts, sunglasses, a very long
## net. Purely visual; game.gd owns movement and the net logic.

const OUTLINE := Layout.OUTLINE
const NET_RADIUS := 30.0
const SKIN := Color("#e8b48a")

var dir := Vector2.UP          ## Direction the net points (into the pool).
var head := Vector2.ZERO       ## Net head position, in global coordinates.
var contents: Array[Color] = []
var capacity := 5
var moving := false
var stunned := 0.0

var _t := 0.0
var _walk := 0.0


func _process(delta: float) -> void:
	_t += delta
	if moving:
		_walk += delta * 12.0
	queue_redraw()


func _ellipse(xf: Transform2D, c: Vector2, r: Vector2, col: Color) -> void:
	draw_set_transform_matrix(xf * Transform2D(0.0, r, 0.0, c))
	draw_circle(Vector2.ZERO, 1.0, col)


func _draw() -> void:
	var h := to_local(head)
	var full := contents.size() >= capacity

	# Pole and net (drawn first so the body overlaps the pole's end).
	draw_line(dir * 16.0, h, OUTLINE, 9.0)
	draw_line(dir * 16.0, h, Color("#d0d4dc"), 5.0)
	draw_circle(h, NET_RADIUS + 4.0, OUTLINE)
	draw_circle(h, NET_RADIUS, Color(1, 1, 1, 0.22))
	for i in range(-2, 3):
		var o := i * 11.0
		var w := sqrt(maxf(NET_RADIUS * NET_RADIUS - o * o, 0.0))
		draw_line(h + Vector2(o, -w), h + Vector2(o, w), Color(1, 1, 1, 0.35), 1.5)
		draw_line(h + Vector2(-w, o), h + Vector2(w, o), Color(1, 1, 1, 0.35), 1.5)
	for i in contents.size():
		var a := float(i) / capacity * TAU + 0.5
		draw_circle(h + Vector2.from_angle(a) * 13.0, 7.0, OUTLINE)
		draw_circle(h + Vector2.from_angle(a) * 13.0, 5.5, contents[i])
	var ring := Color("#ff5a5a") if full and fmod(_t, 0.4) < 0.2 else Color("#ffd23f")
	draw_arc(h, NET_RADIUS + 1.0, 0, TAU, 32, ring, 4.0)

	# Body, rotated to face along `dir`. In the local frame, forward is -Y.
	var xf := Transform2D(dir.angle() + PI * 0.5, Vector2.ZERO)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_circle(Vector2(4, 6), 24.0, Color(0, 0, 0, 0.2))
	draw_set_transform_matrix(xf)
	var step := sin(_walk) * 7.0 if moving else 0.0
	for s: float in [-1.0, 1.0]:  # flip-flops
		_ellipse(xf, Vector2(s * 9, 10 + step * s), Vector2(6, 9), OUTLINE)
		_ellipse(xf, Vector2(s * 9, 10 + step * s), Vector2(4.5, 7.5), Color("#ff7eb6"))
	_ellipse(xf, Vector2(0, 4), Vector2(18, 10), OUTLINE)          # short shorts
	_ellipse(xf, Vector2(0, 4), Vector2(15.5, 8), Color("#2a9d8f"))
	_ellipse(xf, Vector2(0, -2), Vector2(22, 13), OUTLINE)         # shoulders
	_ellipse(xf, Vector2(0, -2), Vector2(19, 10.5), SKIN)
	_ellipse(xf, Vector2(0, -1), Vector2(13, 9), Color("#ff9f1c"))  # tank top
	draw_set_transform_matrix(xf)
	for s: float in [-1.0, 1.0]:  # arms reaching for the pole
		draw_line(Vector2(s * 17, -4), Vector2(s * 5, -20), OUTLINE, 9.0)
		draw_line(Vector2(s * 17, -4), Vector2(s * 5, -20), SKIN, 5.5)
	draw_circle(Vector2(0, -4), 12.0, OUTLINE)                     # head
	draw_circle(Vector2(0, -4), 10.0, SKIN)
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -2), Vector2(-9, -10), Vector2(0, -15), Vector2(10, -10), Vector2(12, -1), Vector2(4, -7), Vector2(-3, -4)]), Color("#ffd23f"))  # surfer hair
	draw_line(Vector2(-8, -12), Vector2(8, -12), OUTLINE, 4.0)       # sunglasses peek out front
	if stunned > 0.0:
		for i in 3:
			var a := _t * 6.0 + i * TAU / 3.0
			draw_circle(Vector2(0, -4) + Vector2.from_angle(a) * 18.0, 3.5, Color("#ffd23f"))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if full:
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(-34, -36), "NET FULL!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, OUTLINE)
		draw_string(font, Vector2(-34, -36), "NET FULL!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ff5a5a"))
