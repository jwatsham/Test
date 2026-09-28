class_name Chiropractor
extends Node2D
## Dr. Crunch. Stands behind the belt; the origin is at belt-top level.
## The body draws behind patients, the arms/hands draw in front of them
## (a child node with a higher z_index) so the hands can squeeze a spine.

const OUTLINE := Color(0.12, 0.1, 0.16)
const COAT := Color("#f7f7f2")
const SKIN := Color("#e8b48a")
const GLOVE := Color("#7ec8e3")
const STACHE := Color("#5b3a1e")

var beat_phase := 0.0

var _slam := 0.0
var _target := Vector2(40, 130)  # (patient width, grab height)
var _sweat := 0.0
var _t := 0.0
var _hands: Node2D


func _ready() -> void:
	_hands = Node2D.new()
	_hands.z_index = 5
	add_child(_hands)
	_hands.draw.connect(_draw_hands)


## Snap the hands onto a patient of the given width at the given height.
func slam(width := 30.0, height := 130.0) -> void:
	_slam = 1.0
	_target = Vector2(width, height)


func sweat() -> void:
	_sweat = 1.5


func _process(delta: float) -> void:
	_t += delta
	_slam = move_toward(_slam, 0.0, delta / 0.16)
	_sweat = move_toward(_sweat, 0.0, delta)
	queue_redraw()
	_hands.queue_redraw()


func _ellipse(c: Vector2, r: Vector2, color: Color) -> void:
	draw_set_transform_matrix(Transform2D(0.0, r, 0.0, c))
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw() -> void:
	var bob := -7.0 * pow(1.0 - beat_phase, 4.0)
	var hc := Vector2(0, -395 + bob)  # head center

	# Coat / torso.
	draw_rect(Rect2(-88, -318, 176, 318), OUTLINE)
	for side: float in [-1.0, 1.0]:
		draw_circle(Vector2(side * 66, -290), 33.0, OUTLINE)
		draw_circle(Vector2(side * 66, -290), 29.0, COAT)
	draw_rect(Rect2(-83, -313, 166, 313), COAT)
	draw_colored_polygon(PackedVector2Array([Vector2(-28, -313), Vector2(28, -313), Vector2(0, -236)]), Color("#9ad1ff"))
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -306), Vector2(7, -306), Vector2(11, -242), Vector2(0, -226), Vector2(-11, -242)]), Color("#e63946"))
	draw_line(Vector2(-28, -313), Vector2(0, -236), OUTLINE, 3.0)
	draw_line(Vector2(28, -313), Vector2(0, -236), OUTLINE, 3.0)
	draw_line(Vector2(0, -236), Vector2(0, 0), OUTLINE, 2.0)
	# Name tag and pocket pens.
	draw_rect(Rect2(20, -276, 56, 20), OUTLINE)
	draw_rect(Rect2(22, -274, 52, 16), Color.WHITE)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(25, -262), "DR.CRUNCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, OUTLINE)
	draw_rect(Rect2(-70, -250, 40, 34), OUTLINE, false, 2.0)
	for k in 3:
		draw_line(Vector2(-64 + k * 12, -250), Vector2(-64 + k * 12, -264), [Color("#e63946"), Color("#3a86ff"), OUTLINE][k], 4.0)

	# Neck and head.
	draw_rect(Rect2(-20, -340 + bob, 40, 32), SKIN)
	for side: float in [-1.0, 1.0]:
		draw_circle(hc + Vector2(side * 57, 4), 14.0, OUTLINE)
		draw_circle(hc + Vector2(side * 57, 4), 11.0, SKIN)
	draw_circle(hc, 60.0, OUTLINE)
	draw_circle(hc, 56.0, SKIN)
	_ellipse(hc + Vector2(-22, -34), Vector2(14, 7), Color(1, 1, 1, 0.35))  # bald shine
	# Head mirror on a headband: essential doctor equipment.
	draw_line(hc + Vector2(-56, -26), hc + Vector2(56, -26), OUTLINE, 7.0)
	draw_circle(hc + Vector2(18, -40), 21.0, OUTLINE)
	draw_circle(hc + Vector2(18, -40), 17.0, Color("#cfd8e3"))
	draw_circle(hc + Vector2(12, -46), 5.0, Color(1, 1, 1, 0.8))

	# Glasses and eyes.
	var surprised := _slam > 0.3
	var brow_lift := 8.0 if surprised else 0.0
	for side: float in [-1.0, 1.0]:
		var e := hc + Vector2(side * 23, 2)
		draw_circle(e, 17.0, OUTLINE)
		draw_circle(e, 14.0, Color.WHITE)
		draw_circle(e + Vector2(0, 1), 6.0 if surprised else 5.0, OUTLINE)
		draw_line(e + Vector2(-12, -24 - brow_lift), e + Vector2(12, -26 - brow_lift + side * 2.0), OUTLINE, 5.0)
	draw_line(hc + Vector2(-6, 2), hc + Vector2(6, 2), OUTLINE, 3.0)

	# Mustache (wiggles on every crack) and mouth.
	var wig := sin(_t * 50.0) * 3.0 * _slam
	for side: float in [-1.0, 1.0]:
		_ellipse(hc + Vector2(side * 20, 30 + wig * side), Vector2(25, 11), OUTLINE)
		_ellipse(hc + Vector2(side * 20, 30 + wig * side), Vector2(22, 8), STACHE)
		draw_circle(hc + Vector2(side * 44, 24 - wig * side), 6.0, STACHE)
	if surprised:
		draw_circle(hc + Vector2(0, 45), 8.0, Color("#7a1f2b"))
	else:
		draw_arc(hc + Vector2(0, 38), 10.0, 0.4, PI - 0.4, 10, OUTLINE, 3.0)

	if _sweat > 0.0:
		var sp := hc + Vector2(62, -24 + (1.5 - _sweat) * 30.0)
		draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -12), sp + Vector2(6, 0), sp + Vector2(-6, 0)]), Color(0.5, 0.8, 1.0, minf(_sweat, 1.0)))
		draw_circle(sp, 6.0, Color(0.5, 0.8, 1.0, minf(_sweat, 1.0)))


func _draw_hands() -> void:
	var beat_bob := 8.0 * pow(1.0 - beat_phase, 3.0)
	var k := smoothstep(0.0, 1.0, _slam)
	for side: float in [-1.0, 1.0]:
		var shoulder := Vector2(side * 70, -290)
		var idle := Vector2(side * 130, -200 + beat_bob)
		var grab := Vector2(side * (_target.x * 0.5 + 22.0), -_target.y)
		var hand := idle.lerp(grab, k)
		var elbow := (shoulder + hand) * 0.5 + Vector2(side * 38, 10)
		var arm := PackedVector2Array([shoulder, elbow, hand])
		_hands.draw_polyline(arm, OUTLINE, 30.0)
		_hands.draw_circle(elbow, 15.0, OUTLINE)
		_hands.draw_polyline(arm, COAT, 23.0)
		_hands.draw_circle(elbow, 11.5, COAT)
		_hands.draw_circle(hand, 23.0, OUTLINE)
		_hands.draw_circle(hand, 19.0, GLOVE)
		_hands.draw_circle(hand + Vector2(-side * 4, -16), 8.0, OUTLINE)
		_hands.draw_circle(hand + Vector2(-side * 4, -16), 5.5, GLOVE)
