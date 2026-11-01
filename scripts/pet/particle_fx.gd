class_name ParticleFx
extends Node3D
## Pooled one-shot bursts of hearts, stars, sparkles, bubbles and paws.
## Textures are drawn once with the Image API; colour comes from the spec palette
## through per-particle vertex colour.

const KINDS: Array[StringName] = [&"heart", &"star", &"sparkle", &"bubble", &"paw"]
const POOL_PER_KIND := 3
const TEX_SIZE := 64
const PALETTE := {
	&"heart": [Color("#FF758F"), Color("#FFB3C1"), Color("#FF758F")],
	&"star": [Color("#FFB703"), Color("#FFB703"), Color("#FFD166")],
	&"sparkle": [Color("#FFB703"), Color("#06D6A0"), Color("#9D4EDD"), Color("#FFB3C1")],
	&"bubble": [Color("#118AB2"), Color("#06D6A0"), Color("#9D4EDD")],
	&"paw": [Color("#9D4EDD"), Color("#FF758F"), Color("#118AB2")],
}

var _pools := {}
var _next := {}


func _ready() -> void:
	for kind in KINDS:
		var pool: Array[CPUParticles3D] = []
		var material := _make_material(kind)
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.13, 0.13)
		mesh.material = material
		for i in POOL_PER_KIND:
			var emitter := _make_emitter(kind, mesh)
			add_child(emitter)
			pool.append(emitter)
		_pools[kind] = pool
		_next[kind] = 0


func burst(kind: StringName, world_position: Vector3, count: int) -> void:
	if not _pools.has(kind) or count <= 0:
		return
	var pool: Array[CPUParticles3D] = _pools[kind]
	var index: int = _next[kind]
	_next[kind] = (index + 1) % pool.size()
	var emitter := pool[index]
	if emitter.amount != count:
		emitter.amount = count
	emitter.global_position = world_position
	emitter.restart()


func _make_emitter(kind: StringName, mesh: QuadMesh) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.92
	p.lifetime = 1.2
	p.local_coords = false
	p.amount = 6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.05
	p.direction = Vector3(0.0, 1.0, 0.25)
	p.spread = 55.0
	p.initial_velocity_min = 0.7
	p.initial_velocity_max = 1.25
	p.gravity = Vector3(0.0, -1.1, 0.0)
	p.damping_min = 0.6
	p.damping_max = 1.2
	p.scale_amount_min = 0.75
	p.scale_amount_max = 1.25
	match kind:
		&"bubble":
			p.gravity = Vector3(0.0, 0.25, 0.0)
			p.initial_velocity_min = 0.35
			p.initial_velocity_max = 0.8
			p.spread = 80.0
			p.lifetime = 1.5
		&"star", &"sparkle":
			p.angle_min = -30.0
			p.angle_max = 30.0
			p.angular_velocity_min = -120.0
			p.angular_velocity_max = 120.0
		&"heart":
			p.gravity = Vector3(0.0, -0.3, 0.0)
			p.angle_min = -15.0
			p.angle_max = 15.0
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.3))
	scale_curve.add_point(Vector2(0.15, 1.0))
	scale_curve.add_point(Vector2(0.8, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.4))
	p.scale_amount_curve = scale_curve
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.7, Color(1, 1, 1, 1))
	p.color_ramp = fade
	var colors: Array = PALETTE[kind]
	var pick := Gradient.new()
	pick.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	pick.set_color(0, colors[0])
	pick.set_offset(1, 1.0)
	pick.set_color(1, colors[colors.size() - 1])
	for i in range(1, colors.size()):
		pick.add_point(float(i) / colors.size(), colors[i])
	p.color_initial_ramp = pick
	return p


func _make_material(kind: StringName) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	m.render_priority = 10
	m.albedo_texture = ImageTexture.create_from_image(make_image(kind))
	return m


## White shape with a soft darker rim, so tinting keeps an edge.
static func make_image(kind: StringName) -> Image:
	var image := Image.create(TEX_SIZE, TEX_SIZE, true, Image.FORMAT_RGBA8)
	var px := 2.0 / TEX_SIZE
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var p := Vector2((x + 0.5) / TEX_SIZE * 2.0 - 1.0, 1.0 - (y + 0.5) / TEX_SIZE * 2.0)
			var d := _sdf(kind, p)
			var alpha := clampf(0.5 - d / px, 0.0, 1.0)
			var shade := lerpf(1.0, 0.78, clampf((d + 0.09) / 0.09, 0.0, 1.0))
			if kind == &"bubble":
				# Hollow bubble: tinted rim, clear middle, white glint.
				var glint := 1.0 - smoothstep(0.1, 0.17, (p - Vector2(-0.32, 0.32)).length())
				var ring := clampf((d + 0.22) / 0.12, 0.0, 1.0)
				alpha *= maxf(lerpf(0.28, 1.0, ring), glint)
				shade = lerpf(shade, 1.6, glint)
			image.set_pixel(x, y, Color(shade, shade, shade, alpha))
	image.generate_mipmaps()
	return image


static func _sdf(kind: StringName, p: Vector2) -> float:
	match kind:
		&"heart":
			# Inigo Quilez's exact heart, scaled to fill the quad.
			var q := Vector2(absf(p.x), p.y + 0.85) / 1.6
			if q.x + q.y > 1.0:
				return ((q - Vector2(0.25, 0.75)).length() - sqrt(2.0) / 4.0) * 1.6
			var b := q - Vector2.ONE * 0.5 * maxf(q.x + q.y, 0.0)
			return sqrt(minf((q - Vector2(0.0, 1.0)).length_squared(), b.length_squared())) * signf(q.x - q.y) * 1.6
		&"star":
			return _star(p, 0.92, 0.42, 5)
		&"sparkle":
			return _star(p, 0.95, 0.22, 4)
		&"bubble":
			return p.length() - 0.88
		&"paw":
			var pad := (p - Vector2(0.0, -0.3)).length() - 0.4
			var toes := minf(
				minf((p - Vector2(-0.55, 0.2)).length(), (p - Vector2(0.55, 0.2)).length()),
				minf((p - Vector2(-0.2, 0.55)).length(), (p - Vector2(0.2, 0.55)).length())) - 0.2
			return minf(pad, toes)
	return p.length() - 0.8


## Approximate distance to a rounded n-point star.
static func _star(p: Vector2, outer: float, inner: float, points: int) -> float:
	var angle := atan2(p.x, p.y)
	var sector := TAU / points
	var a := fposmod(angle + sector * 0.5, sector) - sector * 0.5
	var t := absf(a) / (sector * 0.5)
	var radius := lerpf(outer, inner, pow(t, 0.7))
	return p.length() - radius
