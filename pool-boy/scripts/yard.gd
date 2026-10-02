class_name Yard
extends Node2D
## The backyard. Two layers so overlap reads right:
##   Yard.new()                 -> ground, deck, animated water, ripples, trash can
##   Yard.new() with canopy=true -> tree canopy, homeowner + speech bubble (drawn on top)

const OUTLINE := Layout.OUTLINE

var canopy := false
var wind := Vector2.ZERO          ## Current wind, for leaf sway + streaks.
var bubble_text := ""             ## Mrs. Henderson's current remark.
var bubble_time := 0.0
var bin_glow := 0.0               ## Pulses when the net is full.
var kid_x := -1.0                 ## Neighbor kid peeking over the fence at this x (or -1).
var canopy_alpha := 1.0           ## Fades when the Pool Boy walks under the tree.

var _ripples: Array[Vector3] = []  # x, y, age
var _t := 0.0


func ripple(at: Vector2) -> void:
	_ripples.append(Vector3(at.x, at.y, 0.0))


func _process(delta: float) -> void:
	_t += delta
	bubble_time = maxf(bubble_time - delta, 0.0)
	for i in range(_ripples.size() - 1, -1, -1):
		_ripples[i].z += delta
		if _ripples[i].z > 1.2:
			_ripples.remove_at(i)
	queue_redraw()


func _draw() -> void:
	if canopy:
		_draw_top()
	else:
		_draw_ground()


func _draw_ground() -> void:
	var font := ThemeDB.fallback_font
	# Lawn with mowing stripes.
	draw_rect(Rect2(0, 0, 1280, 720), Color("#7cc45a"))
	for x in range(0, 1280, 64):
		draw_rect(Rect2(x, 0, 32, 720), Color(1, 1, 1, 0.06))
	# Fence along the top.
	draw_rect(Rect2(0, 0, 1280, Layout.FENCE_H), Color("#b07b4a"))
	for x in range(0, 1280, 28):
		draw_line(Vector2(x, 0), Vector2(x, Layout.FENCE_H), Color("#8c5a2b"), 2.0)
	draw_rect(Rect2(0, Layout.FENCE_H - 4, 1280, 6), Color("#8c5a2b"))
	if kid_x >= 0.0:
		# The neighbor's kid, mid-throw.
		draw_circle(Vector2(kid_x, 30), 18.0, OUTLINE)
		draw_circle(Vector2(kid_x, 30), 15.0, Color("#f1c27d"))
		draw_arc(Vector2(kid_x, 26), 15.0, PI, TAU, 12, Color("#e63946"), 8.0)  # cap
		draw_circle(Vector2(kid_x - 5, 32), 2.5, OUTLINE)
		draw_circle(Vector2(kid_x + 5, 32), 2.5, OUTLINE)
		draw_arc(Vector2(kid_x, 36), 5.0, 0.2, PI - 0.2, 8, OUTLINE, 2.0)

	# Deck tiles.
	draw_rect(Layout.DECK.grow(4), OUTLINE)
	draw_rect(Layout.DECK, Color("#e9d8b4"))
	for x in range(int(Layout.DECK.position.x), int(Layout.DECK.end.x), 46):
		draw_line(Vector2(x, Layout.DECK.position.y), Vector2(x, Layout.DECK.end.y), Color("#d6c196"), 2.0)
	for y in range(int(Layout.DECK.position.y), int(Layout.DECK.end.y), 46):
		draw_line(Vector2(Layout.DECK.position.x, y), Vector2(Layout.DECK.end.x, y), Color("#d6c196"), 2.0)

	# Pool coping and water.
	var pool := Layout.POOL
	draw_rect(pool.grow(14), Color("#f7f3ea"))
	draw_rect(pool.grow(14), OUTLINE, false, 3.0)
	draw_rect(pool.grow(2), OUTLINE)
	draw_rect(pool, Color("#2fb6d9"))
	draw_rect(Rect2(pool.position, Vector2(pool.size.x, 26)), Color("#28a3c4"))  # shadow under the near wall
	for x in range(int(pool.position.x) + 40, int(pool.end.x), 40):
		draw_line(Vector2(x, pool.position.y), Vector2(x, pool.end.y), Color(1, 1, 1, 0.07), 1.0)
	for y in range(int(pool.position.y) + 40, int(pool.end.y), 40):
		draw_line(Vector2(pool.position.x, y), Vector2(pool.end.x, y), Color(1, 1, 1, 0.07), 1.0)
	# Wobbly caustic lines.
	for row in 9:
		var y0 := pool.position.y + 25.0 + row * 42.0
		var pts := PackedVector2Array()
		for i in 27:
			var x := pool.position.x + i * pool.size.x / 26.0
			pts.append(Vector2(x, y0 + sin(x * 0.03 + _t * 1.6 + row) * 6.0))
		draw_polyline(pts, Color(0.75, 0.95, 1.0, 0.35), 2.5)
	# Deep-end marking.
	draw_string(font, pool.end - Vector2(150, 18), "DEEP END  9 FT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.5))
	for r in _ripples:
		var k := r.z / 1.2
		draw_arc(Vector2(r.x, r.y), 10.0 + k * 50.0, 0, TAU, 32, Color(1, 1, 1, 0.7 * (1.0 - k)), 3.0)

	# Pool ladder.
	for s: float in [-1.0, 1.0]:
		var lx := pool.position.x + 120.0 + s * 16.0
		draw_line(Vector2(lx, pool.end.y + 12), Vector2(lx, pool.end.y - 36), OUTLINE, 7.0)
		draw_line(Vector2(lx, pool.end.y + 12), Vector2(lx, pool.end.y - 36), Color("#d0d4dc"), 4.0)
	for y in [pool.end.y - 12.0, pool.end.y - 28.0]:
		draw_line(Vector2(pool.position.x + 104, y), Vector2(pool.position.x + 136, y), Color("#d0d4dc"), 4.0)

	# Trash can (top-down: a round bin with a lid).
	var b := Layout.BIN
	if bin_glow > 0.0:
		draw_circle(b, 40.0 + 6.0 * sin(_t * 8.0), Color(1.0, 0.82, 0.25, 0.35 * bin_glow))
	draw_circle(b, 27.0, OUTLINE)
	draw_circle(b, 23.0, Color("#6b7686"))
	draw_circle(b, 15.0, Color("#55606f"))
	draw_line(b + Vector2(-9, 0), b + Vector2(9, 0), OUTLINE, 5.0)
	draw_string_outline(font, b + Vector2(-26, 44), "TRASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, OUTLINE)
	draw_string(font, b + Vector2(-26, 44), "TRASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

	# Tree trunk (the canopy goes on top).
	draw_circle(Layout.TREE, 22.0, OUTLINE)
	draw_circle(Layout.TREE, 18.0, Color("#7a4a26"))


func _draw_top() -> void:
	var font := ThemeDB.fallback_font
	# Tree canopy, swaying in the wind.
	var sway := wind * 0.03 + Vector2(sin(_t * 1.3), cos(_t * 1.1)) * 2.0
	var blobs := [Vector2(0, 0), Vector2(-50, 30), Vector2(55, 20), Vector2(10, 60), Vector2(-20, -45), Vector2(60, -30)]
	var a := canopy_alpha
	for p: Vector2 in blobs:
		draw_circle(Layout.TREE + p + sway, 58.0, Color(OUTLINE, a))
	for p: Vector2 in blobs:
		draw_circle(Layout.TREE + p + sway, 54.0, Color(Color("#3f8f3a"), a))
	for p: Vector2 in blobs:
		draw_circle(Layout.TREE + p + sway + Vector2(-12, -14), 26.0, Color(Color("#56a84a"), a))

	# Wind streaks during gusts.
	if wind.length() > 20.0:
		var d := wind.normalized()
		for i in 10:
			var base := Vector2(fmod(i * 197.0 + _t * wind.length() * 3.0, 1400.0) - 60.0, 80.0 + i * 61.0)
			if d.x < 0.0:
				base.x = 1280.0 - base.x
			draw_line(base, base + d * 70.0, Color(1, 1, 1, 0.45), 3.0)

	# Mrs. Henderson in her lounge chair, under an umbrella.
	var h := Layout.HOMEOWNER
	draw_rect(Rect2(h + Vector2(-26, -50), Vector2(52, 110)), OUTLINE)
	draw_rect(Rect2(h + Vector2(-22, -46), Vector2(44, 102)), Color("#f7f3ea"))
	for y in range(-40, 56, 12):
		draw_line(h + Vector2(-22, y), h + Vector2(22, y), Color("#3fc1e0"), 4.0)
	draw_circle(h + Vector2(0, -28), 17.0, OUTLINE)
	draw_circle(h + Vector2(0, -28), 14.0, Color("#f5d0b0"))
	draw_circle(h + Vector2(0, -34), 22.0, OUTLINE)      # enormous sun hat
	draw_circle(h + Vector2(0, -34), 19.0, Color("#ffd166"))
	draw_circle(h + Vector2(0, -34), 9.0, Color("#e63946"))
	draw_rect(Rect2(h + Vector2(-16, -10), Vector2(32, 40)), Color("#9b5de5"))  # swimsuit
	draw_circle(h + Vector2(24, 10), 8.0, OUTLINE)       # lemonade
	draw_circle(h + Vector2(24, 10), 6.0, Color("#fff3b0"))
	draw_string_outline(font, h + Vector2(-46, 82), "MRS. HENDERSON", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 5, OUTLINE)
	draw_string(font, h + Vector2(-46, 82), "MRS. HENDERSON", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

	if bubble_time > 0.0 and bubble_text != "":
		var fs := 18
		var tw := font.get_string_size(bubble_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var r := Rect2(h + Vector2(-tw - 40, -130), Vector2(tw + 24, 40))
		draw_rect(r.grow(3), OUTLINE)
		draw_rect(r, Color.WHITE)
		draw_colored_polygon(PackedVector2Array([r.end - Vector2(30, 0), r.end - Vector2(6, 0), h + Vector2(-10, -60)]), Color.WHITE)
		draw_string(font, r.position + Vector2(12, 27), bubble_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, OUTLINE)
