class_name UiLayout
extends RefCounted
## Pure layout maths.


## Converts a display safe area (screen pixels) into viewport-space insets (left, top, right, bottom).
static func safe_insets(safe: Rect2i, screen: Vector2i, view_size: Vector2) -> Vector4:
	if screen.x <= 0 or screen.y <= 0:
		return Vector4.ZERO
	var sx := view_size.x / float(screen.x)
	var sy := view_size.y / float(screen.y)
	return Vector4(
		maxf(0.0, safe.position.x) * sx,
		maxf(0.0, safe.position.y) * sy,
		maxf(0.0, screen.x - safe.end.x) * sx,
		maxf(0.0, screen.y - safe.end.y) * sy,
	)
