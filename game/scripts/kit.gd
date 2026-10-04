class_name Kit
extends RefCounted
## Loads the Kenney furniture and character models, centres them on their footprint
## (origin at floor level, middle of the base) and scales them to real-world size.

const SCALE := 2.1
const CHAR_SCALE := 2.0
## The four characters: two boys and two girls, restyled to be cute. "recolor" repaints palette
## cells (x, y in the 16x4 colormap grid) just for that character; "acc" adds little extras.
const CHARS := ["character-male-a", "character-male-d", "character-female-b", "character-female-e"]
const CHAR_STYLES := [
	{"name": "Oggy", "recolor": {Vector2i(3, 2): Color("#86c8ff"), Vector2i(5, 2): Color("#ffffff")}, "acc": ["blush"], "top": Vector2i(3, 2), "bottom": Vector2i(11, 2)},
	{"name": "Jack", "recolor": {Vector2i(9, 2): Color("#ff6fa5")}, "acc": ["blush", "rose"], "top": Vector2i(9, 2), "bottom": Vector2i(9, 3)},
	{"name": "Monica", "recolor": {Vector2i(5, 2): Color("#ff94c4"), Vector2i(15, 2): Color("#b99bff")}, "acc": ["blush", "bow"], "top": Vector2i(5, 2), "bottom": Vector2i(15, 2)},
	{"name": "Olivia", "recolor": {Vector2i(9, 3): Color("#e6d4ff"), Vector2i(7, 3): Color("#bf9cf0"), Vector2i(11, 2): Color("#ff9ec7")}, "acc": ["blush", "flower"], "top": Vector2i(9, 3), "bottom": Vector2i(11, 2)},
]

static var _scenes := {}
static var _bounds := {}


static func path(model_name: String) -> String:
	if model_name.begins_with("character-"):
		return "res://assets/chars/%s.glb" % model_name
	if model_name.begins_with("car:"):
		return "res://assets/vehicles/%s.glb" % model_name.substr(4)
	if model_name.begins_with("ph:"):
		var id := model_name.substr(3)
		return "res://assets/props/%s/%s.gltf" % [id, id]
	return "res://assets/furniture/%s.glb" % model_name


static func scene(model_name: String) -> PackedScene:
	if not _scenes.has(model_name):
		_scenes[model_name] = load(path(model_name))
	return _scenes[model_name]


static func _merge_aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var a: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		acc[0] = a if acc[0] == null else (acc[0] as AABB).merge(a)
	for c in n.get_children():
		_merge_aabb(c, t, acc)


static func bounds(model_name: String) -> AABB:
	if not _bounds.has(model_name):
		var inst := scene(model_name).instantiate()
		var acc := [null]
		for c in inst.get_children():
			_merge_aabb(c, Transform3D(), acc)
		inst.free()
		_bounds[model_name] = acc[0] if acc[0] != null else AABB(Vector3.ZERO, Vector3.ONE * 0.1)
	return _bounds[model_name]


static func size_of(model_name: String, scl := SCALE) -> Vector3:
	return bounds(model_name).size * scl


## A visual-only copy of a model, centred and scaled.
static func model(model_name: String, scl := SCALE) -> Node3D:
	var root := Node3D.new()
	var inst: Node3D = scene(model_name).instantiate()
	var b := bounds(model_name)
	inst.scale = Vector3.ONE * scl
	inst.position = -Vector3(b.get_center().x, b.position.y, b.get_center().z) * scl
	root.add_child(inst)
	return root


static func meshes(n: Node, out: Array = []) -> Array:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		meshes(c, out)
	return out


static func set_shadows(n: Node, on: bool) -> void:
	for mi in meshes(n):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func set_transparency(n: Node, amount: float) -> void:
	for mi in meshes(n):
		(mi as GeometryInstance3D).transparency = amount


## Re-skins a model with the baked-light shader so it matches the pre-lit house.
## Returns the per-instance materials; feed them the room light with set_probe_light().
static func apply_probe_look(root: Node, shape := 0.55) -> Array:
	var tex_shader: Shader = load("res://scripts/probe_tex.gdshader")
	var flat_shader: Shader = load("res://scripts/probe_flat.gdshader")
	var mats := []
	for mi in meshes(root):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for si in m.mesh.get_surface_count():
			var src := m.get_active_material(si)
			var sm := ShaderMaterial.new()
			var b := src as BaseMaterial3D
			sm.shader = tex_shader if b and b.albedo_texture else flat_shader
			sm.set_shader_parameter("shape_shading", shape)
			if b:
				sm.set_shader_parameter("albedo", b.albedo_color)
				if b.albedo_texture:
					sm.set_shader_parameter("albedo_tex", b.albedo_texture)
			m.set_surface_override_material(si, sm)
			mats.append(sm)
	return mats


static func set_probe_light(mats: Array, c: Color) -> void:
	var v := Vector3(c.r, c.g, c.b)
	for sm in mats:
		(sm as ShaderMaterial).set_shader_parameter("flat_light", v)



static var _fredoka: FontFile


## The game's font (Fredoka) with colour emoji bundled as a fallback, so emoji show on every
## phone (some, like vivo, don't have the system emoji font Godot looks for).
static func ui_font() -> FontFile:
	if _fredoka == null:
		_fredoka = load("res://assets/fonts/Fredoka.ttf")
		var emoji: FontFile = load("res://assets/fonts/NotoColorEmoji.ttf")
		_fredoka.fallbacks = [emoji]
		# Label3Ds and anything else using the default font get emoji too
		var fb := ThemeDB.fallback_font
		if fb != null and fb != _fredoka:
			fb.fallbacks = [emoji]
	return _fredoka
