class_name CharRig
extends Node3D
## An animated Kenney mini character. Faces -Z. Animations: idle, walk, sprint, jump, fall,
## crouch, sit, emote-yes, emote-no, interact-right, pick-up, die.

const LOOPING := ["idle", "walk", "sprint", "crouch", "sit", "fall", "static", "holding-both"]

var anim: AnimationPlayer
var current := ""
var model: Node3D
var mats := []
var pose: PoseMod  # leans / tilts / hugs on top of the animation
static var use_probe_look := true  # pre-lit materials; brightness follows the room via set_light()


var outfit := {}   # wardrobe: {"top": Color, "bottom": Color, "acc": String}


func setup(char_index: int, outfit_in := {}) -> void:
	outfit = outfit_in
	_idx = clampi(char_index, 0, Kit.CHARS.size() - 1)
	var char_name: String = Kit.CHARS[_idx]
	model = Kit.scene(char_name).instantiate()
	model.scale = Vector3.ONE * Kit.CHAR_SCALE
	model.rotation.y = PI
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	if anim != null:
		for n in LOOPING:
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		play("idle")
	Kit.set_shadows(model, false)
	var sk: Skeleton3D = null
	for n in model.find_children("*", "Skeleton3D", true, false):
		sk = n
	if sk:
		pose = PoseMod.new()
		sk.add_child(pose)
	_skin()
	if use_probe_look:
		mats = Kit.apply_probe_look(model, 0.6)
	if sk:
		_accessories(sk)
	_blob()


static var _blob_mat: StandardMaterial3D


## A soft round shadow under the feet: looks good and costs almost nothing.
func _blob() -> void:
	if _blob_mat == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.45))
		g.set_color(1, Color(0, 0, 0, 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_blob_mat = StandardMaterial3D.new()
		_blob_mat.albedo_texture = gt
		_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 1.1)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _blob_mat
	mi.rotation.x = -PI / 2.0
	mi.position.y = 0.03
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


static var _skins := {}   # character index -> its own recoloured material


## Each character gets its own copy of the shared colour palette with their outfit colours.
static func _skin_for(idx: int, fit := {}) -> StandardMaterial3D:
	var key := "%d|%s|%s" % [idx, fit.get("top", ""), fit.get("bottom", "")]
	if _skins.has(key):
		return _skins[key]
	var img: Image = (load("res://assets/chars/Textures/colormap.png") as Texture2D).get_image()
	img.decompress()
	var style: Dictionary = Kit.CHAR_STYLES[idx] if idx < Kit.CHAR_STYLES.size() else {}
	var rec: Dictionary = style.get("recolor", {}).duplicate()
	for part in ["top", "bottom"]:
		if fit.has(part) and style.has(part):
			rec[style[part]] = fit[part] if fit[part] is Color else Color(str(fit[part]))
	for cell in rec:
		var c: Color = rec[cell]
		# repaint both columns of the swatch, keeping its light-to-dark shading
		for cx in [cell.x - 1, cell.x]:
			var x0: int = cx * 32
			var y0: int = cell.y * 128
			var mean := 0.0
			for y in 128:
				for x in 32:
					mean += img.get_pixel(x0 + x, y0 + y).get_luminance()
			mean = maxf(mean / 4096.0, 0.01)
			for y in 128:
				for x in 32:
					var k := img.get_pixel(x0 + x, y0 + y).get_luminance() / mean
					img.set_pixel(x0 + x, y0 + y, Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0), minf(c.b * k, 1.0)))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 0.75
	_skins[key] = m
	return m


var _idx := 0


func _skin() -> void:
	var mat := _skin_for(_idx, outfit)
	for mi in Kit.meshes(model):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			m.set_surface_override_material(i, mat)


# ---------- cute extras: blush, a bow, a flower, a rose ----------

static var _soft: ImageTexture
const BLUSH_SHADER := """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform sampler2D tex : filter_linear;
uniform vec3 flat_light = vec3(0.8);
void fragment() {
	ALBEDO = vec3(1.0, 0.45, 0.6) * flat_light * 1.1;
	ALPHA = texture(tex, UV).a * 0.6;
}"""


func _accessories(sk: Skeleton3D) -> void:
	var style: Dictionary = Kit.CHAR_STYLES[_idx] if _idx < Kit.CHAR_STYLES.size() else {}
	var acc: Array = style.get("acc", []).duplicate()
	if outfit.has("acc"):
		# the wardrobe pick replaces the character's own extra (blush always stays)
		acc = ["blush"]
		if str(outfit["acc"]) != "":
			acc.append(str(outfit["acc"]))
	if acc.is_empty():
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "head"
	sk.add_child(att)
	var hold := Node3D.new()   # positions below are relative to the head bone, in model units
	hold.position = Vector3(0, -0.34325, 0.002361)
	att.add_child(hold)
	if "blush" in acc:
		if _soft == null:
			var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
			for y in 32:
				for x in 32:
					var d := Vector2((x - 15.5) / 15.5, (y - 15.5) / 15.5).length()
					img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
			_soft = ImageTexture.create_from_image(img)
		var sh := Shader.new()
		sh.code = BLUSH_SHADER
		for sx in [-1.0, 1.0]:
			var q := QuadMesh.new()
			q.size = Vector2(0.085, 0.05)
			var mi := MeshInstance3D.new()
			mi.mesh = q
			var bm := ShaderMaterial.new()
			bm.shader = sh
			bm.set_shader_parameter("tex", _soft)
			mi.material_override = bm
			mi.position = Vector3(sx * 0.135, 0.445, 0.1705)
			hold.add_child(mi)
			mats.append(bm)
	var extras := Node3D.new()
	hold.add_child(extras)
	if "bow" in acc:
		var pink := Color("#ff5fa2")
		Build.ball(extras, 0.06, Vector3(-0.07, 0.735, 0.0), pink, Vector3(1.2, 0.8, 0.6))
		Build.ball(extras, 0.06, Vector3(0.07, 0.735, 0.0), pink, Vector3(1.2, 0.8, 0.6))
		Build.ball(extras, 0.032, Vector3(0, 0.735, 0.01), Color("#ff3d8b"))
	if "flower" in acc:
		var at := Vector3(0.17, 0.64, 0.15)
		for k in 5:
			var a := k * TAU / 5.0
			Build.ball(extras, 0.034, at + Vector3(cos(a), sin(a), 0) * 0.038, Color("#ffc2dd"), Vector3(1, 1, 0.5))
		Build.ball(extras, 0.024, at + Vector3(0, 0, 0.012), Color("#ffd23d"))
	if "cap" in acc:
		var cc: Color = outfit.get("top", Color("#ff6f91")) if outfit.get("top") is Color else Color("#ff6f91")
		Build.cube(extras, Vector3(0.5, 0.13, 0.46), Vector3(0, 0.72, -0.01), cc)
		Build.cube(extras, Vector3(0.44, 0.03, 0.2), Vector3(0, 0.665, 0.27), cc.darkened(0.15))
		Build.ball(extras, 0.03, Vector3(0, 0.795, 0), Color.WHITE)
	if "crown" in acc:
		var gold := Color("#ffcf3f")
		Build.cyl(extras, 0.15, 0.15, 0.06, Vector3(0, 0.74, 0), gold, 12)
		for k in 5:
			var a := k * TAU / 5.0
			Build.cube(extras, Vector3(0.05, 0.1, 0.05), Vector3(cos(a) * 0.13, 0.81, sin(a) * 0.13), gold)
			Build.ball(extras, 0.022, Vector3(cos(a) * 0.13, 0.87, sin(a) * 0.13), Color("#ff4f8b") if k % 2 == 0 else Color("#7fdbff"))
	if "headphones" in acc:
		var hp := Color("#ff8fc0")
		Build.cube(extras, Vector3(0.54, 0.05, 0.08), Vector3(0, 0.75, 0), hp)
		for sx in [-1.0, 1.0]:
			Build.cube(extras, Vector3(0.05, 0.22, 0.06), Vector3(sx * 0.27, 0.64, 0), hp)
			Build.ball(extras, 0.085, Vector3(sx * 0.27, 0.5, 0.0), Color("#fff1f7"), Vector3(0.6, 1, 1))
	if "sunglasses" in acc:
		var dark := Color("#1d1824")
		for sx in [-1.0, 1.0]:
			Build.cube(extras, Vector3(0.14, 0.085, 0.02), Vector3(sx * 0.09, 0.535, 0.178), dark)
		Build.cube(extras, Vector3(0.06, 0.02, 0.02), Vector3(0, 0.555, 0.178), dark)
	if "rose" in acc:
		# a little rose tucked in the suit pocket (on the torso, so it follows the body)
		var tatt := BoneAttachment3D.new()
		tatt.bone_name = "torso"
		sk.add_child(tatt)
		var r := Node3D.new()
		r.position = Vector3(0.1, 0.13, 0.15)
		tatt.add_child(r)
		Build.ball(r, 0.03, Vector3.ZERO, Color("#e8255a"))
		Build.cube(r, Vector3(0.012, 0.05, 0.012), Vector3(0, -0.035, 0), Color("#3f8a3a"))
		mats.append_array(Kit.apply_probe_look(r, 0.4))
	mats.append_array(Kit.apply_probe_look(extras, 0.4))


func play(n: String, speed := 1.0) -> void:
	if anim == null or not anim.has_animation(n):
		return
	anim.speed_scale = speed
	if n != current:
		current = n
		anim.play(n, 0.18)


## One-shot gesture, returns to the looping animation afterwards.
func gesture(n: String) -> void:
	if anim == null or not anim.has_animation(n):
		return
	current = n
	anim.play(n, 0.12)


func busy() -> bool:
	return anim != null and current in ["emote-yes", "emote-no", "interact-right", "pick-up", "jump"] and anim.is_playing() and anim.current_animation == current


func set_light(c: Color) -> void:
	Kit.set_probe_light(mats, c)


func set_ghost(on: bool) -> void:
	Kit.set_transparency(self, 0.65 if on else 0.0)


## Romantic poses: "kiss", "hug", "dance", "cuddle" or "" to let go.
## side = +1 / -1 so two people lean towards each other.
func set_pose(kind: String, side := 1.0) -> void:
	if pose == null:
		return
	match kind:
		"kiss":
			pose.set_pose(0.22, 0.16 * side, 0.1, 0.35)
		"hug":
			# cheek to cheek: head tipped onto the other's shoulder, arms right round
			pose.set_pose(0.1, 0.32 * side, -0.05, 1.0, 0.05 * side)
		"dance":
			pose.set_pose(0.04, 0.0, 0.0, 0.55)
		"cuddle":
			# on the sofa: leaning into each other, head on the shoulder
			pose.set_pose(0.02, 0.24 * side, 0.08, 0.0, 0.1 * side)
		_:
			pose.set_pose(0.0, 0.0, 0.0, 0.0)
			pose.clear_live()


func set_live(lean: float, roll: float, arm_l: float, arm_r: float) -> void:
	if pose:
		pose.live = {"lean": lean, "roll": roll, "arm_l": arm_l, "arm_r": arm_r}


const DANCE_LEN := 3.2


## The 💃 Dance prank: bounce on the beat, twist the hips, pump the arms, and a spin to finish.
## t = seconds since the dance started. Returns {bounce, twist, roll, arm_l, arm_r}.
static func groove(t: float) -> Dictionary:
	var beat := t * TAU * 2.0                     # two bounces a second
	var out := {"bounce": absf(sin(beat * 0.5)) * 0.14, "twist": sin(beat * 0.5) * 0.45, "roll": sin(beat * 0.5) * 0.12,
		"arm_l": 1.5 + 1.2 * sin(beat), "arm_r": 1.5 - 1.2 * sin(beat)}
	if t > 1.6 and t < 2.4:
		# both arms up, wave them
		out["arm_l"] = 2.7 + 0.25 * sin(beat * 1.5)
		out["arm_r"] = 2.7 - 0.25 * sin(beat * 1.5)
	if t > 2.4:
		var k := clampf((t - 2.4) / 0.8, 0.0, 1.0)
		out["twist"] = smoothstep(0.0, 1.0, k) * TAU
		out["arm_l"] = 2.2
		out["arm_r"] = 2.2
		out["bounce"] = sin(k * PI) * 0.25
	return out


func dance_tick(t: float, base_yaw: float, visual: Node3D) -> void:
	if t >= DANCE_LEN:
		set_live(0.0, 0.0, 0.0, 0.0)
		return
	var g := groove(t)
	visual.position.y = g["bounce"]
	visual.rotation.y = base_yaw + g["twist"]
	set_live(0.0, g["roll"], g["arm_l"], g["arm_r"])
