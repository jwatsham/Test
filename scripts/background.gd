class_name Background
extends Node2D
## The clinic: wallpaper, questionable diplomas, floor, and the conveyor belt.

const W := 1280.0
const BELT_Y := 560.0
const OUTLINE := Color(0.12, 0.1, 0.16)

var scroll := 0.0  ## Belt travel in pixels. Belt moves left as this grows.
var pulse := 0.0   ## 0..1, spikes on each beat.


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# Wall.
	draw_rect(Rect2(0, 0, W, 720), Color("#f4d9c6").lerp(Color("#ffe8d6"), pulse * 0.4))
	for x in range(0, int(W), 80):
		draw_rect(Rect2(x, 0, 40, 430), Color(1, 1, 1, 0.18))
	draw_rect(Rect2(0, 430, W, 130), Color("#7fb7a4"))
	draw_rect(Rect2(0, 424, W, 10), Color("#5e8f7e"))

	_frame(Rect2(60, 80, 190, 130), Color("#fff6d5"), ["DEFINITELY", "A REAL", "DEGREE"], 20)
	_frame(Rect2(780, 60, 200, 150), Color("#d5ecff"), ["SPINES", "R US"], 34)
	_frame(Rect2(1010, 90, 220, 120), Color("#ffd6e0"), ["TODAY ONLY:", "1 FREE CRACK", "(no refunds)"], 18)

	# Clock that ticks with the beat.
	var cc := Vector2(640, 110)
	draw_circle(cc, 44.0, OUTLINE)
	draw_circle(cc, 39.0, Color.WHITE)
	var ang := -PI * 0.5 + scroll * 0.004
	draw_line(cc, cc + Vector2.from_angle(ang) * 30.0, OUTLINE, 3.0)
	draw_line(cc, cc + Vector2.from_angle(ang * 0.1) * 20.0, OUTLINE, 5.0)
	draw_string(font, cc + Vector2(-26, 70), "CRACK O'CLOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, OUTLINE)

	# Floor.
	draw_rect(Rect2(0, 604, W, 116), Color("#b98b62"))
	for y in [640, 680]:
		draw_line(Vector2(0, y), Vector2(W, y), Color("#9c7350"), 2.0)

	# Belt frame legs and rollers.
	for x in range(40, int(W), 160):
		draw_rect(Rect2(x - 8, BELT_Y + 40, 16, 80), Color("#555566"))
	draw_rect(Rect2(0, BELT_Y - 4, W, 52), OUTLINE)
	draw_rect(Rect2(0, BELT_Y, W, 44), Color("#3b3b46"))
	var off := fposmod(-scroll, 60.0)
	for i in 24:
		var x := off + i * 60.0 - 60.0
		draw_line(Vector2(x, BELT_Y + 4), Vector2(x + 20, BELT_Y + 40), Color("#55556a"), 6.0)
	draw_rect(Rect2(0, BELT_Y, W, 5), Color("#6b6b80"))
	for x in range(20, int(W), 80):
		var rc := Vector2(x, BELT_Y + 44)
		draw_circle(rc, 10.0, OUTLINE)
		draw_circle(rc, 7.0, Color("#9a9aac"))
		var a := -scroll / 10.0
		draw_line(rc, rc + Vector2.from_angle(a) * 7.0, OUTLINE, 2.0)


func _frame(r: Rect2, col: Color, lines: Array, size: int) -> void:
	var font := ThemeDB.fallback_font
	draw_rect(r.grow(8), Color("#8c5a2b"))
	draw_rect(r.grow(8), OUTLINE, false, 3.0)
	draw_rect(r, col)
	var y := r.position.y + (r.size.y - lines.size() * (size + 6)) * 0.5 + size
	for line in lines:
		var tw := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, Vector2(r.get_center().x - tw * 0.5, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, OUTLINE)
		y += size + 6
