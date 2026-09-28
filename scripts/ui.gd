class_name UI
extends RefCounted
## Small helpers for chunky cartoon text.

const OUTLINE := Color(0.12, 0.1, 0.16)


static func label(text: String, size: int, color := Color.WHITE, outline := 10) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = OUTLINE
	ls.shadow_size = 0
	ls.shadow_color = Color(0, 0, 0, 0.35)
	ls.shadow_offset = Vector2(3, 4)
	l.label_settings = ls
	return l


## Spawns text at `pos` (its center) that pops in, floats up and fades out.
static func popup(parent: Node, text: String, pos: Vector2, size := 44, color := Color.WHITE, rise := 70.0, duration := 0.6) -> void:
	var l := label(text, size, color)
	parent.add_child(l)
	l.size = l.get_minimum_size()
	l.pivot_offset = l.size * 0.5
	l.position = pos - l.size * 0.5
	l.rotation = randf_range(-0.18, 0.18)
	l.scale = Vector2(0.4, 0.4)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - rise, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tw.chain().tween_callback(l.queue_free)
