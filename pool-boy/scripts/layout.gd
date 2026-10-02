class_name Layout
extends RefCounted
## Where everything in the backyard lives (1280x720 screen).

const POOL := Rect2(250, 170, 780, 390)   ## The water.
const DECK := Rect2(180, 100, 920, 530)   ## Walkable area (minus the pool).
const BIN := Vector2(214, 598)            ## Trash can: dump the net here.
const TREE := Vector2(105, 115)           ## Leaves fall from here.
const HOMEOWNER := Vector2(1190, 600)     ## Mrs. Henderson's lounge chair.
const FENCE_H := 44.0
const OUTLINE := Color(0.12, 0.1, 0.16)


## Closest point on the pool's rim (or inside it) to `p`.
static func pool_point(p: Vector2) -> Vector2:
	return p.clamp(POOL.position, POOL.end)


## Unit vector from `p` pointing into the pool.
static func into_pool(p: Vector2) -> Vector2:
	var d := pool_point(p) - p
	if d.length() < 0.01:
		return (POOL.get_center() - p).normalized()
	return d.normalized()
