class_name UiIcons
extends RefCounted
## Vector icons drawn with CanvasItem primitives so nothing depends on an emoji font.
## Every icon fits in a square of half-size `r` around `c`; `bg` is the surface behind it (for cut-outs).

const OUTLINE := UiStyle.BROWN


static func draw(ci: CanvasItem, id: StringName, c: Vector2, r: float, bg := UiStyle.CREAM) -> void:
	match id:
		&"milk": _milk(ci, c, r)
		&"fish": _fish(ci, c, r)
		&"yarn": _yarn(ci, c, r)
		&"bone": _bone(ci, c, r)
		&"ball": _ball(ci, c, r)
		&"water": _water(ci, c, r)
		&"carrot": _carrot(ci, c, r)
		&"clover": _clover(ci, c, r)
		&"bell": _bell(ci, c, r)
		&"sun": _sun(ci, c, r)
		&"sunrise": _horizon_sun(ci, c, r, Color("FFB067"))
		&"sunset": _horizon_sun(ci, c, r, Color("FF8FA3"))
		&"moon": _moon(ci, c, r)
		&"zoom_in": _magnifier(ci, c, r, true)
		&"zoom_out": _magnifier(ci, c, r, false)
		&"gear": _gear(ci, c, r, bg)
		&"close": _close(ci, c, r)
		&"pet_cat": _cat(ci, c, r)
		&"pet_dog": _dog(ci, c, r)
		&"pet_rabbit": _rabbit(ci, c, r)
		&"waves": _waves(ci, c, r)
		&"speech": _speech(ci, c, r)
		&"paw": _paw(ci, c, r)


# Helpers -------------------------------------------------------------------

static func _w(r: float) -> float:
	return maxf(2.5, r * 0.09)


static func _pts(c: Vector2, r: float, unit: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in unit:
		out.append(c + p * r)
	return out


static func _poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, r: float) -> void:
	ci.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, OUTLINE, _w(r), true)


static func _disc(ci: CanvasItem, c: Vector2, rad: float, fill: Color, r: float) -> void:
	ci.draw_circle(c, rad, fill, true, -1.0, true)
	ci.draw_circle(c, rad, OUTLINE, false, _w(r), true)


static func _ellipse(c: Vector2, rx: float, ry: float, rot := 0.0, n := 28, from := 0.0, to := TAU) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var a := from + (to - from) * float(i) / float(n)
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return out


static func _arc_pts(c: Vector2, rad: float, a0: float, a1: float, n := 16) -> PackedVector2Array:
	return _ellipse(c, rad, rad, 0.0, n, a0, a1)


static func _eyes(ci: CanvasItem, c: Vector2, r: float, gap: float, size: float) -> void:
	ci.draw_circle(c + Vector2(-gap, 0) * r, size * r, OUTLINE, true, -1.0, true)
	ci.draw_circle(c + Vector2(gap, 0) * r, size * r, OUTLINE, true, -1.0, true)


static func _smile(ci: CanvasItem, c: Vector2, r: float, width: float) -> void:
	ci.draw_polyline(_arc_pts(c + Vector2(0, -width * 0.4 * r), width * r, deg_to_rad(30), deg_to_rad(150), 8), OUTLINE, _w(r) * 0.8, true)


static func _cheeks(ci: CanvasItem, c: Vector2, r: float, gap: float, size: float) -> void:
	var pink := Color(1.0, 0.62, 0.7, 0.75)
	ci.draw_circle(c + Vector2(-gap, 0) * r, size * r, pink, true, -1.0, true)
	ci.draw_circle(c + Vector2(gap, 0) * r, size * r, pink, true, -1.0, true)


# Toys ----------------------------------------------------------------------

static func _milk(ci: CanvasItem, c: Vector2, r: float) -> void:
	var glass := _pts(c, r, [Vector2(-0.52, -0.7), Vector2(0.52, -0.7), Vector2(0.64, 0.82), Vector2(-0.64, 0.82)])
	ci.draw_colored_polygon(glass, Color("F2F9FF"))
	ci.draw_colored_polygon(_pts(c, r, [Vector2(-0.56, -0.3), Vector2(0.56, -0.3), Vector2(0.64, 0.82), Vector2(-0.64, 0.82)]), Color("FFFFFF"))
	ci.draw_line(c + Vector2(-0.56, -0.3) * r, c + Vector2(0.56, -0.3) * r, Color("D9E8F5"), _w(r), true)
	var closed := glass.duplicate()
	closed.append(glass[0])
	ci.draw_polyline(closed, OUTLINE, _w(r) * 1.1, true)
	_eyes(ci, c + Vector2(0, 0.32 * r), r, 0.22, 0.07)
	_smile(ci, c + Vector2(0, 0.5 * r), r, 0.12)
	_cheeks(ci, c + Vector2(0, 0.45 * r), r, 0.38, 0.08)


static func _fish(ci: CanvasItem, c: Vector2, r: float) -> void:
	var orange := Color("FFA05C")
	_poly(ci, _pts(c, r, [Vector2(0.4, 0), Vector2(0.98, -0.45), Vector2(0.78, 0), Vector2(0.98, 0.45)]), Color("FF8A4C"), r)
	_poly(ci, _pts(c, r, [Vector2(-0.2, -0.38), Vector2(0.05, -0.72), Vector2(0.3, -0.36)]), Color("FF8A4C"), r)
	var body := PackedVector2Array()
	for p in _ellipse(c + Vector2(-0.1, 0) * r, 0.75 * r, 0.48 * r):
		body.append(p)
	body.remove_at(body.size() - 1)
	_poly(ci, body, orange, r)
	ci.draw_colored_polygon(_ellipse(c + Vector2(-0.12, 0.22) * r, 0.5 * r, 0.16 * r, 0.0, 20), Color("FFD6A8"))
	ci.draw_polyline(_arc_pts(c + Vector2(0.18, 0) * r, 0.34 * r, deg_to_rad(110), deg_to_rad(250), 8), Color("E56F2E"), _w(r), true)
	_disc(ci, c + Vector2(-0.42, -0.1) * r, 0.14 * r, Color.WHITE, r)
	ci.draw_circle(c + Vector2(-0.44, -0.09) * r, 0.065 * r, OUTLINE, true, -1.0, true)


static func _yarn(ci: CanvasItem, c: Vector2, r: float) -> void:
	var cc := c + Vector2(-0.1, -0.05) * r
	var rad := 0.8 * r
	ci.draw_polyline(PackedVector2Array([
		c + Vector2(0.4, 0.6) * r, c + Vector2(0.6, 0.88) * r, c + Vector2(0.92, 0.8) * r,
		c + Vector2(0.95, 0.55) * r, c + Vector2(0.75, 0.6) * r]), Color("E8738F"), _w(r) * 1.1, true)
	_disc(ci, cc, rad, Color("FF9EB8"), r)
	for y0 in [-0.38, -0.05, 0.28]:
		var line := PackedVector2Array()
		var half := sqrt(maxf(0.01, 1.0 - y0 * y0)) * 0.92
		for i in 13:
			var t := float(i) / 12.0
			var x := lerpf(-half, half, t)
			line.append(cc + Vector2(x, y0 + 0.16 * (1.0 - pow(x / half, 2.0))).rotated(deg_to_rad(-28)) * rad)
		ci.draw_polyline(line, Color("E8738F"), _w(r) * 0.9, true)


static func _bone(ci: CanvasItem, c: Vector2, r: float) -> void:
	var fill := Color("FFF9EC")
	var rot := deg_to_rad(-35)
	var w := _w(r) * 1.1
	var knobs: Array[Vector2] = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			knobs.append(c + Vector2(0.64 * sx, 0.2 * sy).rotated(rot) * r)
	var bar := PackedVector2Array()
	for p: Vector2 in [Vector2(-0.64, -0.17), Vector2(0.64, -0.17), Vector2(0.64, 0.17), Vector2(-0.64, 0.17)]:
		bar.append(c + p.rotated(rot) * r)
	var grow := PackedVector2Array()
	for p: Vector2 in [Vector2(-0.64, -0.17 - w / r), Vector2(0.64, -0.17 - w / r), Vector2(0.64, 0.17 + w / r), Vector2(-0.64, 0.17 + w / r)]:
		grow.append(c + p.rotated(rot) * r)
	ci.draw_colored_polygon(grow, OUTLINE)
	for k in knobs:
		ci.draw_circle(k, 0.25 * r + w, OUTLINE, true, -1.0, true)
	ci.draw_colored_polygon(bar, fill)
	for k in knobs:
		ci.draw_circle(k, 0.25 * r, fill, true, -1.0, true)
	ci.draw_line(c + Vector2(-0.3, 0.07).rotated(rot) * r, c + Vector2(0.3, 0.07).rotated(rot) * r, Color("EAD9BC"), _w(r), true)


static func _ball(ci: CanvasItem, c: Vector2, r: float) -> void:
	_disc(ci, c, 0.78 * r, Color("D8EE6B"), r)
	var white := Color("FFFFF0")
	ci.draw_polyline(_arc_pts(c + Vector2(-1.25, 0) * r, 1.0 * r, deg_to_rad(-34), deg_to_rad(34), 12), white, _w(r) * 1.2, true)
	ci.draw_polyline(_arc_pts(c + Vector2(1.25, 0) * r, 1.0 * r, deg_to_rad(146), deg_to_rad(214), 12), white, _w(r) * 1.2, true)
	ci.draw_circle(c + Vector2(-0.3, -0.38) * r, 0.1 * r, Color(1, 1, 1, 0.7), true, -1.0, true)


static func _water(ci: CanvasItem, c: Vector2, r: float) -> void:
	var center := Vector2(0, 0.25)
	var pts := PackedVector2Array([c + Vector2(0, -0.95) * r])
	for p in _arc_pts(center, 0.62, deg_to_rad(211.1), deg_to_rad(-31.1), 24):
		pts.append(c + p * r)
	_poly(ci, pts, Color("7EC8F5"), r)
	ci.draw_polyline(_arc_pts(c + center * r, 0.42 * r, deg_to_rad(140), deg_to_rad(190), 6), Color(1, 1, 1, 0.85), _w(r) * 1.3, true)
	_eyes(ci, c + Vector2(0, 0.28 * r), r, 0.2, 0.065)
	_smile(ci, c + Vector2(0, 0.46 * r), r, 0.1)


static func _carrot(ci: CanvasItem, c: Vector2, r: float) -> void:
	var rot := deg_to_rad(32)
	r *= 1.15
	c += Vector2(-0.04, 0.0) * r
	var green := Color("7BC96F")
	for a in [-24.0, 0.0, 24.0]:
		var base := Vector2(0, -0.55)
		var tip := base + Vector2(0, -0.45).rotated(deg_to_rad(a))
		var mid := (base + tip) * 0.5
		var leaf := _ellipse(Vector2.ZERO, 0.13, 0.3, deg_to_rad(a))
		var moved := PackedVector2Array()
		for p in leaf:
			moved.append(c + (mid + p).rotated(rot) * r)
		_poly(ci, moved, green, r)
	var body: Array = [Vector2(-0.4, -0.45), Vector2(-0.24, -0.6), Vector2(0.24, -0.6), Vector2(0.4, -0.45),
		Vector2(0.14, 0.5), Vector2(0.0, 0.92), Vector2(-0.14, 0.5)]
	var pts := PackedVector2Array()
	for p: Vector2 in body:
		pts.append(c + p.rotated(rot) * r)
	_poly(ci, pts, Color("FF9A3C"), r)
	for y in [-0.25, 0.05, 0.32]:
		var half := lerpf(0.3, 0.1, (y + 0.45) / 0.95)
		ci.draw_line(c + Vector2(-half, y).rotated(rot) * r, c + Vector2(-half * 0.2, y).rotated(rot) * r, Color("E5762A"), _w(r), true)


static func _clover(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_polyline(PackedVector2Array([c + Vector2(0.1, 0.2) * r, c + Vector2(0.3, 0.55) * r, c + Vector2(0.28, 0.9) * r]), Color("5FAE74"), _w(r) * 1.6, true)
	var leaves: Array[Vector2] = []
	for p: Vector2 in [Vector2(-0.34, -0.34), Vector2(0.34, -0.34), Vector2(-0.34, 0.34), Vector2(0.34, 0.34)]:
		leaves.append(c + p * r)
	var w := _w(r) * 1.1
	for l in leaves:
		ci.draw_circle(l, 0.4 * r + w, OUTLINE, true, -1.0, true)
	ci.draw_circle(c, 0.3 * r + w, OUTLINE, true, -1.0, true)
	for l in leaves:
		ci.draw_circle(l, 0.4 * r, Color("8FD9A0"), true, -1.0, true)
	ci.draw_circle(c, 0.3 * r, Color("8FD9A0"), true, -1.0, true)
	for l in leaves:
		ci.draw_circle(l + Vector2(-0.1, -0.1) * r, 0.07 * r, Color(1, 1, 1, 0.6), true, -1.0, true)
	ci.draw_circle(c, 0.09 * r, Color("5FAE74"), true, -1.0, true)


static func _bell(ci: CanvasItem, c: Vector2, r: float) -> void:
	var gold := Color("FFCB4D")
	ci.draw_circle(c + Vector2(0, 0.74) * r, 0.19 * r, Color("F0A92E"), true, -1.0, true)
	ci.draw_circle(c + Vector2(0, 0.74) * r, 0.19 * r, OUTLINE, false, _w(r), true)
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		pts.append(c + Vector2(cos(a) * 0.62, 0.1 + sin(a) * 0.72) * r)
	for p: Vector2 in [Vector2(0.64, 0.15), Vector2(0.84, 0.5), Vector2(-0.84, 0.5), Vector2(-0.64, 0.15)]:
		pts.append(c + p * r)
	_poly(ci, pts, gold, r)
	_poly(ci, _pts(c, r, [Vector2(-0.92, 0.46), Vector2(0.92, 0.46), Vector2(0.92, 0.64), Vector2(-0.92, 0.64)]), Color("F0A92E"), r)
	ci.draw_polyline(_arc_pts(c + Vector2(0, 0.1) * r, 0.44 * r, deg_to_rad(200), deg_to_rad(250), 6), Color(1, 1, 1, 0.8), _w(r) * 1.4, true)
	_disc(ci, c + Vector2(0, -0.78) * r, 0.1 * r, gold, r)


# Header --------------------------------------------------------------------

static func _sun(ci: CanvasItem, c: Vector2, r: float) -> void:
	var ray := Color("FF9F2E")
	for i in 8:
		var d := Vector2.RIGHT.rotated(TAU * float(i) / 8.0)
		ci.draw_line(c + d * 0.66 * r, c + d * 0.94 * r, ray, _w(r) * 1.6, true)
		ci.draw_circle(c + d * 0.94 * r, _w(r) * 0.8, ray, true, -1.0, true)
		ci.draw_circle(c + d * 0.66 * r, _w(r) * 0.8, ray, true, -1.0, true)
	_disc(ci, c, 0.46 * r, Color("FFD23C"), r)
	_eyes(ci, c + Vector2(0, -0.04 * r), r, 0.16, 0.05)
	_smile(ci, c + Vector2(0, 0.14 * r), r, 0.1)


static func _horizon_sun(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var base := c + Vector2(0, 0.28) * r
	for i in 5:
		var d := Vector2.RIGHT.rotated(PI + PI * float(i) / 4.0)
		ci.draw_line(base + d * 0.64 * r, base + d * 0.92 * r, color.darkened(0.15), _w(r) * 1.6, true)
	_poly(ci, PackedVector2Array(_arc_pts(base, 0.46 * r, PI, TAU, 16)), color, r)
	ci.draw_line(c + Vector2(-0.9, 0.28) * r, c + Vector2(0.9, 0.28) * r, OUTLINE, _w(r) * 1.3, true)
	ci.draw_line(c + Vector2(-0.5, 0.55) * r, c + Vector2(0.5, 0.55) * r, OUTLINE, _w(r) * 1.1, true)


static func _moon(ci: CanvasItem, c: Vector2, r: float) -> void:
	var o := c
	var orad := 0.72 * r
	var shift := Vector2(0.34, -0.14) * r
	var irad := 0.6 * r
	var base := shift.angle()
	var outer := PackedVector2Array()
	for i in 41:
		var p := o + Vector2.from_angle(base + 0.0001 + TAU * float(i) / 40.0) * orad
		if p.distance_to(o + shift) >= irad:
			outer.append(p)
	var inner := PackedVector2Array()
	var back := (-shift).angle()
	for i in 41:
		var p := o + shift + Vector2.from_angle(back - PI + TAU * float(i) / 40.0) * irad
		if p.distance_to(o) <= orad:
			inner.append(p)
	if inner.size() > 0 and outer.size() > 0 and inner[0].distance_to(outer[outer.size() - 1]) > inner[inner.size() - 1].distance_to(outer[outer.size() - 1]):
		inner.reverse()
	outer.append_array(inner)
	if outer.size() >= 3:
		_poly(ci, outer, Color("FFE59A"), r)
	_star(ci, c + Vector2(0.52, -0.5) * r, 0.2 * r, Color("FFE59A"), r)
	_star(ci, c + Vector2(0.62, 0.3) * r, 0.11 * r, Color("FFE59A"), r)


static func _star(ci: CanvasItem, c: Vector2, rad: float, fill: Color, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var rr := rad if i % 2 == 0 else rad * 0.4
		pts.append(c + Vector2.from_angle(-PI / 2.0 + TAU * float(i) / 8.0) * rr)
	_poly(ci, pts, fill, r * 0.7)


static func _magnifier(ci: CanvasItem, c: Vector2, r: float, plus: bool) -> void:
	var lens := c + Vector2(-0.14, -0.14) * r
	ci.draw_line(lens + Vector2(0.4, 0.4) * r, c + Vector2(0.76, 0.76) * r, OUTLINE, _w(r) * 2.4, true)
	ci.draw_circle(c + Vector2(0.76, 0.76) * r, _w(r) * 1.2, OUTLINE, true, -1.0, true)
	ci.draw_circle(lens, 0.52 * r, Color("EAF6FF"), true, -1.0, true)
	ci.draw_circle(lens, 0.52 * r, OUTLINE, false, _w(r) * 1.6, true)
	var half := 0.24 * r
	ci.draw_line(lens + Vector2(-half, 0), lens + Vector2(half, 0), OUTLINE, _w(r) * 1.3, true)
	if plus:
		ci.draw_line(lens + Vector2(0, -half), lens + Vector2(0, half), OUTLINE, _w(r) * 1.3, true)


static func _gear(ci: CanvasItem, c: Vector2, r: float, bg: Color) -> void:
	var pts := PackedVector2Array()
	var teeth := 8
	for i in teeth:
		var a := TAU * float(i) / float(teeth)
		var step := TAU / float(teeth)
		for k in [[-0.30, 0.62], [-0.16, 0.9], [0.16, 0.9], [0.30, 0.62]]:
			pts.append(c + Vector2.from_angle(a + step * k[0]) * k[1] * r)
	_poly(ci, pts, Color("E2B887"), r)
	_disc(ci, c, 0.28 * r, bg, r)


static func _close(ci: CanvasItem, c: Vector2, r: float) -> void:
	var d := 0.5 * r
	ci.draw_line(c + Vector2(-d, -d), c + Vector2(d, d), OUTLINE, _w(r) * 2.2, true)
	ci.draw_line(c + Vector2(-d, d), c + Vector2(d, -d), OUTLINE, _w(r) * 2.2, true)
	ci.draw_circle(c + Vector2(-d, -d), _w(r) * 1.1, OUTLINE, true, -1.0, true)
	ci.draw_circle(c + Vector2(d, d), _w(r) * 1.1, OUTLINE, true, -1.0, true)
	ci.draw_circle(c + Vector2(-d, d), _w(r) * 1.1, OUTLINE, true, -1.0, true)
	ci.draw_circle(c + Vector2(d, -d), _w(r) * 1.1, OUTLINE, true, -1.0, true)


# Pet faces and pill glyphs ---------------------------------------------------

static func _face_bits(ci: CanvasItem, c: Vector2, r: float) -> void:
	_eyes(ci, c + Vector2(0, -0.08 * r), r, 0.3, 0.09)


static func _cat(ci: CanvasItem, c: Vector2, r: float) -> void:
	var fur := Color("FFC48A")
	_poly(ci, _pts(c, r, [Vector2(-0.8, -0.1), Vector2(-0.72, -0.9), Vector2(-0.18, -0.55)]), fur, r)
	_poly(ci, _pts(c, r, [Vector2(0.8, -0.1), Vector2(0.72, -0.9), Vector2(0.18, -0.55)]), fur, r)
	_disc(ci, c + Vector2(0, 0.08) * r, 0.82 * r, fur, r)
	_face_bits(ci, c, r)
	ci.draw_circle(c + Vector2(0, 0.14) * r, 0.08 * r, Color("FF8FA3"), true, -1.0, true)
	_smile(ci, c + Vector2(0, 0.34) * r, r, 0.14)
	for s in [-1.0, 1.0]:
		ci.draw_line(c + Vector2(0.5 * s, 0.2) * r, c + Vector2(0.98 * s, 0.14) * r, OUTLINE, _w(r) * 0.6, true)
		ci.draw_line(c + Vector2(0.5 * s, 0.32) * r, c + Vector2(0.98 * s, 0.4) * r, OUTLINE, _w(r) * 0.6, true)


static func _dog(ci: CanvasItem, c: Vector2, r: float) -> void:
	var gold := Color("F2B45E")
	for s in [-1.0, 1.0]:
		var ear := _ellipse(c + Vector2(0.78 * s, 0.0) * r, 0.28 * r, 0.52 * r, deg_to_rad(12.0 * s))
		_poly(ci, ear, Color("D9954A"), r)
	_disc(ci, c + Vector2(0, 0.05) * r, 0.78 * r, gold, r)
	ci.draw_colored_polygon(_ellipse(c + Vector2(0, 0.3) * r, 0.4 * r, 0.3 * r, 0.0, 20), Color("FFE9C9"))
	_face_bits(ci, c, r)
	ci.draw_circle(c + Vector2(0, 0.2) * r, 0.11 * r, OUTLINE, true, -1.0, true)
	_smile(ci, c + Vector2(0, 0.42) * r, r, 0.14)


static func _rabbit(ci: CanvasItem, c: Vector2, r: float) -> void:
	for s in [-1.0, 1.0]:
		var ear := _ellipse(c + Vector2(0.36 * s, -0.66) * r, 0.2 * r, 0.52 * r, deg_to_rad(10.0 * s))
		_poly(ci, ear, Color("FFFFFF"), r)
		ci.draw_colored_polygon(_ellipse(c + Vector2(0.36 * s, -0.62) * r, 0.09 * r, 0.34 * r, deg_to_rad(10.0 * s), 12), Color("FFC2D1"))
	_disc(ci, c + Vector2(0, 0.14) * r, 0.74 * r, Color("FFFFFF"), r)
	_eyes(ci, c + Vector2(0, 0.05 * r), r, 0.28, 0.09)
	ci.draw_circle(c + Vector2(0, 0.26) * r, 0.08 * r, Color("FF8FA3"), true, -1.0, true)
	_smile(ci, c + Vector2(0, 0.48) * r, r, 0.13)
	_cheeks(ci, c + Vector2(0, 0.3) * r, r, 0.5, 0.1)


static func _waves(ci: CanvasItem, c: Vector2, r: float) -> void:
	var col := Color("D98A1F")
	ci.draw_circle(c + Vector2(-0.6, 0) * r, 0.18 * r, col, true, -1.0, true)
	for i in 3:
		var rad := (0.45 + 0.3 * i) * r
		ci.draw_polyline(_arc_pts(c + Vector2(-0.6, 0) * r, rad, deg_to_rad(-40), deg_to_rad(40), 10), col, _w(r) * 1.8, true)


static func _speech(ci: CanvasItem, c: Vector2, r: float) -> void:
	var fill := Color("FFFFFF")
	var body := _ellipse(c + Vector2(0, -0.1) * r, 0.9 * r, 0.65 * r)
	ci.draw_colored_polygon(body, fill)
	ci.draw_colored_polygon(_pts(c, r, [Vector2(-0.4, 0.4), Vector2(-0.6, 0.9), Vector2(0.0, 0.5)]), fill)
	ci.draw_polyline(body, OUTLINE, _w(r), true)
	ci.draw_polyline(PackedVector2Array([c + Vector2(-0.52, 0.42) * r, c + Vector2(-0.6, 0.9) * r, c + Vector2(-0.05, 0.55) * r]), OUTLINE, _w(r), true)
	for i in 3:
		ci.draw_circle(c + Vector2(-0.4 + 0.4 * i, -0.1) * r, 0.1 * r, OUTLINE, true, -1.0, true)


static func _paw(ci: CanvasItem, c: Vector2, r: float) -> void:
	var fill := Color("FF9EB8")
	for p: Vector2 in [Vector2(-0.62, -0.1), Vector2(-0.24, -0.58), Vector2(0.24, -0.58), Vector2(0.62, -0.1)]:
		ci.draw_circle(c + p * r, 0.2 * r + _w(r), OUTLINE, true, -1.0, true)
	var pad := _ellipse(c + Vector2(0, 0.42) * r, 0.58 * r, 0.46 * r)
	ci.draw_colored_polygon(_ellipse(c + Vector2(0, 0.42) * r, 0.58 * r + _w(r), 0.46 * r + _w(r)), OUTLINE)
	for p: Vector2 in [Vector2(-0.62, -0.1), Vector2(-0.24, -0.58), Vector2(0.24, -0.58), Vector2(0.62, -0.1)]:
		ci.draw_circle(c + p * r, 0.2 * r, fill, true, -1.0, true)
	ci.draw_colored_polygon(pad, fill)
