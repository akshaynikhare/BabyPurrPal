class_name UiAtlas
extends RefCounted
## Renders the static vector art (button faces, glyphs, switch knob) once into a single texture at startup.
## Controls then blit one region instead of replaying dozens of vector draw commands every redraw.

const WIDTH := 1024
const SCALE := 2.0
const PAD := 4
const USERS := &"ui_atlas_users"
const BUTTON := 96.0
const TOY_BUTTON := 156.0
const GLYPH := 48.0
const PAW := 84.0
const KNOB := 56.0
const PHASES := [
	[&"sunrise", &"sunrise", UiStyle.PEACH],
	[&"day", &"sun", UiStyle.SKY],
	[&"sunset", &"sunset", UiStyle.PINK],
	[&"night", &"moon", Color("C9CCF2")],
]
const GLYPHS := [&"pet_cat", &"pet_dog", &"pet_rabbit", &"waves", &"speech"]

static var texture: Texture2D
static var regions := {}
static var _baking := false
static var _material: CanvasItemMaterial


static func face_key(icon: StringName, fill: Color) -> StringName:
	return StringName("%s_%s" % [icon, fill.to_html(false)])


static func glyph_key(id: StringName) -> StringName:
	return StringName("glyph_" + id)


## The viewport result is premultiplied, so everything blitted from the atlas needs this blend mode.
static func material() -> CanvasItemMaterial:
	if _material == null:
		_material = CanvasItemMaterial.new()
		_material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	return _material


static func draw_region(ci: CanvasItem, key: StringName, rect: Rect2) -> void:
	if texture != null and regions.has(key):
		ci.draw_texture_rect_region(texture, rect, regions[key])


static func specs() -> Array:
	var out: Array = []
	for p: Array in PHASES:
		out.append({"key": face_key(p[1], p[2]), "kind": &"face", "icon": p[1], "fill": p[2], "size": Vector2.ONE * BUTTON})
	for icon: StringName in [&"zoom_in", &"zoom_out"]:
		out.append({"key": face_key(icon, UiStyle.MINT), "kind": &"face", "icon": icon, "fill": UiStyle.MINT, "size": Vector2.ONE * BUTTON})
	out.append({"key": face_key(&"gear", UiStyle.PINK), "kind": &"face", "icon": &"gear", "fill": UiStyle.PINK, "size": Vector2.ONE * BUTTON})
	out.append({"key": face_key(&"close", UiStyle.PEACH), "kind": &"face", "icon": &"close", "fill": UiStyle.PEACH, "size": Vector2.ONE * BUTTON})
	for pet in 3:
		for toy: Dictionary in ToyCatalog.toys_for(pet):
			out.append({"key": face_key(toy.id, toy.fill), "kind": &"face", "icon": toy.id, "fill": toy.fill, "size": Vector2.ONE * TOY_BUTTON})
	for g: StringName in GLYPHS:
		out.append({"key": glyph_key(g), "kind": &"glyph", "icon": g, "fill": UiStyle.CREAM, "size": Vector2.ONE * GLYPH})
	out.append({"key": &"glyph_paw", "kind": &"glyph", "icon": &"paw", "fill": UiStyle.CREAM, "size": Vector2.ONE * PAW})
	out.append({"key": &"knob", "kind": &"knob", "icon": &"", "fill": UiStyle.CREAM, "size": Vector2.ONE * KNOB})
	return out


## Shelf-packs the specs; returns the atlas pixel size and fills `placed` with [spec, inner Rect2] pairs.
static func pack(list: Array, placed: Array) -> Vector2i:
	var x := 0
	var y := 0
	var shelf := 0
	for spec: Dictionary in list:
		var px: Vector2 = (spec.size as Vector2) * SCALE
		var cell := px + Vector2.ONE * PAD * 2.0
		if x + int(cell.x) > WIDTH:
			x = 0
			y += shelf
			shelf = 0
		placed.append([spec, Rect2(Vector2(x + PAD, y + PAD), px)])
		x += int(cell.x)
		shelf = maxi(shelf, int(cell.y))
	return Vector2i(WIDTH, y + shelf)


static func bake(host: Node) -> void:
	if texture != null or _baking or DisplayServer.get_name() == "headless":
		return
	_baking = true
	var placed: Array = []
	var atlas_size := pack(specs(), placed)
	var viewport := SubViewport.new()
	viewport.size = atlas_size
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := _Painter.new()
	painter.items = placed
	painter.size = Vector2(atlas_size)
	viewport.add_child(painter)
	host.add_child(viewport)
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	_baking = false
	if image == null:
		return
	for item: Array in placed:
		regions[item[0].key] = item[1]
	texture = ImageTexture.create_from_image(image)
	host.get_tree().call_group(USERS, "queue_redraw")


static func paint_face(ci: CanvasItem, icon: StringName, fill: Color, size: Vector2) -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - UiStyle.SHADOW_OFFSET - 2.0
	ci.draw_circle(c + Vector2(0, UiStyle.SHADOW_OFFSET), r, UiStyle.SHADOW, true, -1.0, true)
	ci.draw_circle(c, r, UiStyle.BROWN, true, -1.0, true)
	ci.draw_circle(c, r - UiStyle.BORDER, fill, true, -1.0, true)
	UiIcons.draw(ci, icon, c, r * 0.74, fill)


static func paint_knob(ci: CanvasItem, size: Vector2) -> void:
	var c := size * 0.5 - Vector2(0, 2)
	ci.draw_circle(c + Vector2(0, 3), 22.0, UiStyle.SHADOW, true, -1.0, true)
	ci.draw_circle(c, 22.0, UiStyle.CREAM, true, -1.0, true)
	ci.draw_circle(c, 22.0, UiStyle.BROWN, false, 4.0, true)


class _Painter extends Control:
	var items: Array = []

	func _draw() -> void:
		for item: Array in items:
			var spec: Dictionary = item[0]
			var rect: Rect2 = item[1]
			draw_set_transform(rect.position, 0.0, Vector2.ONE * UiAtlas.SCALE)
			match spec.kind:
				&"face":
					UiAtlas.paint_face(self, spec.icon, spec.fill, spec.size)
				&"glyph":
					UiIcons.draw(self, spec.icon, spec.size * 0.5, spec.size.x * 0.46, UiStyle.CREAM)
				&"knob":
					UiAtlas.paint_knob(self, spec.size)
