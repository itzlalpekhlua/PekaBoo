class_name Build
extends RefCounted
## Mesh helpers plus the characters and disguise props, all made from simple shapes.

const PROP_TYPES := ["plant", "lamp", "box", "chair", "teddy", "trash"]
const PROP_NAMES := {"plant": "a plant", "lamp": "a lamp", "box": "a box", "chair": "a chair", "teddy": "a teddy", "trash": "a trash can"}
const PROP_SIZE := {
	"plant": Vector3(0.6, 1.1, 0.6), "lamp": Vector3(0.45, 1.7, 0.45), "box": Vector3(0.65, 0.6, 0.65),
	"chair": Vector3(0.55, 1.0, 0.55), "teddy": Vector3(0.6, 0.85, 0.5), "trash": Vector3(0.46, 0.7, 0.46),
}

static var _mats := {}


static func mat(c: Color, rough := 0.85, emit := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [c.to_html(true), rough, emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if c.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


static func add_mesh(parent: Node, m: Mesh, pos: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(c)
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func cube(parent: Node, size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return add_mesh(parent, b, pos, c, rot)


static func cyl(parent: Node, r_top: float, r_bot: float, h: float, pos: Vector3, c: Color, segs := 16) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	return add_mesh(parent, m, pos, c)


static func ball(parent: Node, r: float, pos: Vector3, c: Color, scl := Vector3.ONE) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 16
	m.rings = 8
	var mi := add_mesh(parent, m, pos, c)
	mi.scale = scl
	return mi


static func collider(parent: Node, size: Vector3, pos: Vector3, rot_y := 0.0) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	sb.rotation.y = rot_y
	parent.add_child(sb)
	return sb


## A round, friendly blob with big eyes. Faces -Z.
static func character(c: Color) -> Node3D:
	var n := Node3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.36
	body.height = 1.25
	body.radial_segments = 16
	body.rings = 6
	add_mesh(n, body, Vector3(0, 0.72, 0), c)
	ball(n, 0.34, Vector3(0, 1.3, 0), c)
	var white := Color("#ffffff")
	var black := Color("#1d1420")
	for s in [-1.0, 1.0]:
		ball(n, 0.1, Vector3(0.13 * s, 1.38, -0.27), white)
		ball(n, 0.05, Vector3(0.13 * s, 1.38, -0.36), black)
		ball(n, 0.06, Vector3(0.22 * s, 1.24, -0.27), Color("#ff9fb5"), Vector3(1, 0.6, 0.4))
		ball(n, 0.15, Vector3(0.17 * s, 0.07, -0.05), c.darkened(0.35), Vector3(1, 0.55, 1.3))
	cube(n, Vector3(0.12, 0.03, 0.02), Vector3(0, 1.17, -0.33), black)
	if c.a < 0.99:
		for child in n.get_children():
			if child is MeshInstance3D:
				var mm: StandardMaterial3D = child.material_override
				var col := mm.albedo_color
				col.a = c.a
				child.material_override = mat(col)
	return n


static func prop(kind: String) -> Node3D:
	var n := Node3D.new()
	match kind:
		"plant":
			cyl(n, 0.22, 0.16, 0.4, Vector3(0, 0.2, 0), Color("#c0623a"))
			ball(n, 0.32, Vector3(0, 0.72, 0), Color("#3f9a4a"), Vector3(1, 1.2, 1))
			ball(n, 0.2, Vector3(0.15, 0.98, 0.05), Color("#55b860"))
			ball(n, 0.17, Vector3(-0.14, 0.9, -0.08), Color("#4aa957"))
		"lamp":
			cyl(n, 0.2, 0.22, 0.05, Vector3(0, 0.025, 0), Color("#3a3340"))
			cyl(n, 0.025, 0.025, 1.3, Vector3(0, 0.67, 0), Color("#3a3340"), 8)
			var shade := cyl(n, 0.14, 0.27, 0.35, Vector3(0, 1.45, 0), Color("#ffe9b0"))
			shade.material_override = mat(Color("#ffe9b0"), 0.9, 0.7)
		"box":
			cube(n, Vector3(0.65, 0.6, 0.65), Vector3(0, 0.3, 0), Color("#b88a5a"))
			cube(n, Vector3(0.66, 0.02, 0.14), Vector3(0, 0.605, 0), Color("#e0c690"))
		"chair":
			var wood := Color("#9a6a3f")
			cube(n, Vector3(0.5, 0.08, 0.5), Vector3(0, 0.48, 0), wood)
			cube(n, Vector3(0.5, 0.55, 0.07), Vector3(0, 0.79, 0.22), wood)
			for x in [-0.21, 0.21]:
				for z in [-0.21, 0.21]:
					cube(n, Vector3(0.06, 0.45, 0.06), Vector3(x, 0.22, z), wood.darkened(0.25))
		"teddy":
			var fur := Color("#a86b3c")
			var light := Color("#e2b98d")
			ball(n, 0.26, Vector3(0, 0.3, 0), fur, Vector3(1, 1.1, 0.9))
			ball(n, 0.13, Vector3(0, 0.28, -0.17), light)
			ball(n, 0.19, Vector3(0, 0.68, 0), fur)
			ball(n, 0.075, Vector3(0, 0.64, -0.17), light)
			ball(n, 0.025, Vector3(0, 0.66, -0.24), Color("#1d1420"))
			for s in [-1.0, 1.0]:
				ball(n, 0.07, Vector3(0.13 * s, 0.83, 0), fur)
				ball(n, 0.025, Vector3(0.07 * s, 0.73, -0.16), Color("#1d1420"))
				ball(n, 0.09, Vector3(0.2 * s, 0.1, -0.12), fur)
		"trash":
			cyl(n, 0.23, 0.19, 0.65, Vector3(0, 0.325, 0), Color("#7e8b94"))
			cyl(n, 0.245, 0.245, 0.04, Vector3(0, 0.67, 0), Color("#5d6870"))
			cube(n, Vector3(0.14, 0.04, 0.04), Vector3(0, 0.71, 0), Color("#5d6870"))
	return n


static func banana() -> Node3D:
	var n := Node3D.new()
	var y := Color("#ffd93b")
	ball(n, 0.12, Vector3(0, 0.03, 0), y, Vector3(1.4, 0.25, 0.6))
	for i in 3:
		var a := TAU * i / 3.0
		ball(n, 0.08, Vector3(cos(a) * 0.14, 0.03, sin(a) * 0.14), y, Vector3(1.6, 0.25, 0.6)).rotation.y = -a
	return n


static func cushion() -> Node3D:
	var n := Node3D.new()
	ball(n, 0.2, Vector3(0, 0.04, 0), Color("#ff5c8a"), Vector3(1, 0.25, 1))
	ball(n, 0.05, Vector3(0, 0.05, -0.22), Color("#ff5c8a"), Vector3(1, 0.6, 1.4))
	return n


static var _fx_mats := {}


## One-shot particle bursts for the pranks: fart cloud, confetti, hearts, music notes, poof.
static var _heart_tex: ImageTexture


## A soft white heart (tinted by the particle colour).
static func heart_texture() -> ImageTexture:
	if _heart_tex == null:
		var n := 64
		var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				# classic heart curve, sampled a few times per pixel for smooth edges
				var cov := 0.0
				for sy in 2:
					for sx in 2:
						var u := ((x + 0.25 + sx * 0.5) / n - 0.5) * 2.6
						var v := (0.5 - (y + 0.25 + sy * 0.5) / n) * 2.6 + 0.25
						var f := pow(u * u + v * v - 1.0, 3.0) - u * u * v * v * v
						if f <= 0.0:
							cov += 0.25
				img.set_pixel(x, y, Color(1, 1, 1, cov))
		img.generate_mipmaps()
		_heart_tex = ImageTexture.create_from_image(img)
	return _heart_tex


static func burst(parent: Node, pos: Vector3, kind: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = false
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	p.mesh = q
	if not _fx_mats.has("p"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_fx_mats["p"] = m
	p.material_override = _fx_mats["p"]
	if kind == "hearts":
		if not _fx_mats.has("heart"):
			var hm := StandardMaterial3D.new()
			hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			hm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			hm.vertex_color_use_as_albedo = true
			hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			hm.albedo_texture = heart_texture()
			_fx_mats["heart"] = hm
		p.material_override = _fx_mats["heart"]
		q.size = Vector2(0.16, 0.16)
	var g := Gradient.new()
	match kind:
		"fart":
			p.amount = 40
			p.lifetime = 2.2
			p.explosiveness = 0.6
			p.direction = Vector3.UP
			p.spread = 180.0
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 1.2
			p.gravity = Vector3(0, 0.25, 0)
			p.scale_amount_min = 3.0
			p.scale_amount_max = 6.0
			g.set_color(0, Color(0.55, 0.8, 0.2, 0.75))
			g.set_color(1, Color(0.4, 0.6, 0.1, 0.0))
			p.color_ramp = g
			pos += Vector3(0, 0.5, 0)
		"confetti":
			p.amount = 90
			p.lifetime = 2.0
			p.direction = Vector3.UP
			p.spread = 70.0
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 8.0
			p.gravity = Vector3(0, -6, 0)
			p.damping_min = 2.0
			p.damping_max = 4.0
			p.angular_velocity_min = -400.0
			p.angular_velocity_max = 400.0
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.0
			var cols := Gradient.new()
			cols.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
			cols.colors = PackedColorArray([Color("#ff4f86"), Color("#ffc23d"), Color("#3f86ff"), Color("#2fc77a"), Color("#a36bff")])
			cols.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
			p.color_initial_ramp = cols
			pos += Vector3(0, 1.2, 0)
		"smoke":
			p.amount = 50
			p.lifetime = 3.0
			p.explosiveness = 0.8
			p.direction = Vector3.UP
			p.spread = 180.0
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 3.0
			p.damping_min = 1.0
			p.damping_max = 2.0
			p.gravity = Vector3(0, 0.3, 0)
			p.scale_amount_min = 6.0
			p.scale_amount_max = 10.0
			g.set_color(0, Color(0.95, 0.95, 0.95, 0.85))
			g.set_color(1, Color(0.85, 0.85, 0.85, 0.0))
			p.color_ramp = g
			pos += Vector3(0, 0.8, 0)
		"hearts", "notes":
			p.amount = 14
			p.lifetime = 1.8
			p.explosiveness = 1.0 if kind == "hearts" else 0.4
			p.lifetime_randomness = 0.45 if kind == "hearts" else 0.0
			p.direction = Vector3.UP
			p.spread = 35.0
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 2.0
			p.gravity = Vector3.ZERO
			p.scale_amount_min = 1.5
			p.scale_amount_max = 2.5
			var c := Color("#ff4f86") if kind == "hearts" else Color("#ffd23d")
			g.set_color(0, Color(c.r, c.g, c.b, 0.0))
			g.add_point(0.08, c)
			g.set_color(1, Color(c.r, c.g, c.b, 0.0))
			p.color = c
			p.color_ramp = g
			pos += Vector3(0, 1.6, 0)
		_:
			p.amount = 24
			p.lifetime = 0.7
			p.direction = Vector3.UP
			p.spread = 180.0
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 3.0
			p.gravity = Vector3.ZERO
			p.damping_min = 3.0
			p.damping_max = 5.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 3.0
			g.set_color(0, Color(1, 1, 1, 0.9))
			g.set_color(1, Color(1, 1, 1, 0.0))
			p.color_ramp = g
			pos += Vector3(0, 0.8, 0)
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p
