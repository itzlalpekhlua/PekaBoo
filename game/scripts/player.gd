class_name Player
extends CharacterBody3D
## The local player: third-person camera, movement, crouching, hiding and disguises.

const SPEED := 3.6
const RUN := 6.2
const CROUCH_SPEED := 1.8
const GRAVITY := 22.0
const JUMP := 7.2
const BOUNCE := 11.5
const STAND_H := 1.5
const RIDE_HEIGHT := 0.42
const CROUCH_H := 0.85

var yaw := 0.0
var pitch := -0.25
var move_input := Vector2.ZERO
var run := false
var crouch := false
var frozen := false
var anim_hold := ""  # chill mode: "sit" / "holding-both" while not moving
var sitting := false
var held := false   # moved by a script (ladder, holding hands): no gravity or collisions
var lying := false
var _stand_pos := Vector3.ZERO


func sit_at(seat: Vector3, seat_yaw: float) -> void:
	_stand_pos = global_position
	sitting = true
	frozen = true
	velocity = Vector3.ZERO
	global_position = seat
	yaw = seat_yaw
	visual.rotation.y = seat_yaw
	anim_hold = "sit"
	_shape_owner_disabled(true)


## Lie on your back (stargazing), head towards +z.
func lie_at(pos: Vector3) -> void:
	sit_at(pos, 0.0)
	lying = true
	anim_hold = "idle"
	visual.rotation = Vector3(PI / 2.0, 0.0, 0.0)


func stand_up() -> void:
	if not sitting:
		return
	if lying:
		lying = false
		visual.rotation = Vector3(0.0, visual.rotation.y, 0.0)
	visual.rotation.x = 0.0
	sitting = false
	frozen = false
	anim_hold = ""
	global_position = _stand_pos
	_shape_owner_disabled(false)


func _shape_owner_disabled(off: bool) -> void:
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = off
var role := ""
var ghost := false
var disguise := ""
var disguise_scale := Kit.SCALE
var disguise_yaw := 0.0
var prop_locked := false
var hide_spot := -1
var char_index := 0
var stun := 0.0
var jump_req := false
var house: House
var cam_dist := 4.0

var visual: Node3D
var rig: CharRig
var prop_node: Node3D
var pivot: Node3D
var arm: Node3D
var shoulder := 0.55
var _arm_len := 4.0
var _shoulder_now := 0.55
var _cast_q := PhysicsShapeQueryParameters3D.new()
var cam: Camera3D
var flashlight: SpotLight3D
var bubble: Label3D
var _shape: CapsuleShape3D
var _prop_shape := CylinderShape3D.new()
var _col: CollisionShape3D
var _bubble_t := 0.0
var _step_d := 0.0
var _spot_exit := Vector3.ZERO
var _shake := 0.0
var _air_t := 0.0
var _hop := 0.0
var _dance := 0.0
var _dance_yaw := 0.0
var boost := 0.0
var _prop_mats := []
var _probe_t := 0.0
var no_probe := false
var no_boom := false


func setup(idx: int, h: House) -> void:
	char_index = idx
	house = h
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50)
	_col = CollisionShape3D.new()
	_shape = CapsuleShape3D.new()
	_shape.radius = 0.36
	_shape.height = STAND_H
	_col.shape = _shape
	_col.position.y = STAND_H / 2.0
	add_child(_col)
	visual = Node3D.new()
	add_child(visual)
	_rebuild()
	pivot = Node3D.new()
	pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	pivot.position = Vector3(0, 1.45, 0)
	add_child(pivot)
	# the camera boom: we do our own smoothed collision test instead of SpringArm3D,
	# which snapped in and out every frame in tight spaces like the hedge maze
	arm = Node3D.new()
	pivot.add_child(arm)
	var sph := SphereShape3D.new()
	sph.radius = 0.22
	_cast_q.shape = sph
	_cast_q.collision_mask = 1
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.05
	cam.far = 120.0
	arm.add_child(cam)
	cam.current = true
	flashlight = SpotLight3D.new()
	flashlight.spot_range = 18.0
	flashlight.spot_angle = 28.0
	flashlight.light_energy = 3.5
	flashlight.light_color = Color("#fff4d8")
	flashlight.visible = false
	cam.add_child(flashlight)
	bubble = make_bubble()
	bubble.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(bubble)


static func make_bubble() -> Label3D:
	var l := Label3D.new()
	l.font = Kit.ui_font()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 72
	l.outline_size = 18
	l.pixel_size = 0.0045
	l.modulate = Color.WHITE
	l.outline_modulate = Color("#2b2033")
	l.position.y = 2.1
	l.width = 600
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.render_priority = 2
	l.visible = false
	return l


func _rebuild() -> void:
	for ch in visual.get_children():
		ch.queue_free()
	rig = null
	prop_node = null
	if disguise != "":
		prop_node = Kit.model(disguise, disguise_scale)
		prop_node.rotation.y = disguise_yaw
		visual.add_child(prop_node)
		_prop_mats = Kit.apply_probe_look(prop_node, 0.3)
		Kit.set_shadows(prop_node, true)
	else:
		rig = CharRig.new()
		visual.add_child(rig)
		rig.setup(char_index, outfit)
		rig.set_ghost(ghost)
	visual.visible = hide_spot < 0


func set_char(idx: int) -> void:
	char_index = idx
	_rebuild()


var outfit := {}


func set_outfit(o: Dictionary) -> void:
	outfit = o
	_rebuild()


## Collision size for an object you turn into: a cylinder around its footprint, so a sofa
## or wardrobe can't be pushed into walls the way a person-sized capsule allowed.
static func prop_dims(model_name: String, scl: float) -> Vector2:
	var sz := Kit.size_of(model_name, scl)
	return Vector2(clampf(maxf(sz.x, sz.z) * 0.5 * 0.95, 0.25, 1.35), clampf(sz.y, 0.3, 2.3))


## Finds a spot near you where the object fits without touching walls or furniture.
## Returns Vector3.INF if there's no room nearby.
func find_room_for(model_name: String, scl: float) -> Vector3:
	var d := prop_dims(model_name, scl)
	var cyl := CylinderShape3D.new()
	cyl.radius = d.x
	cyl.height = d.y - 0.08
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cyl
	q.collision_mask = 1
	var space := get_world_3d().direct_space_state
	var base := global_position
	for dist in [0.0, 0.35, 0.7, 1.05, 1.4]:
		var steps: int = 1 if dist == 0.0 else 12
		for k in steps:
			var a := TAU * k / steps
			var p: Vector3 = base + Vector3(cos(a), 0, sin(a)) * dist
			q.transform = Transform3D(Basis(), p + Vector3(0, d.y / 2.0 + 0.06, 0))
			if space.intersect_shape(q, 1).is_empty():
				return p
	return Vector3.INF


func set_disguise(model_name: String, scl := Kit.SCALE) -> void:
	disguise = model_name
	disguise_scale = scl
	disguise_yaw = visual.rotation.y if model_name != "" else 0.0
	prop_locked = false
	visual.rotation.y = 0.0
	if model_name != "":
		var d := prop_dims(model_name, scl)
		_prop_shape.radius = d.x
		_prop_shape.height = d.y
		_col.shape = _prop_shape
		_col.position.y = d.y / 2.0
	else:
		_col.shape = _shape
		_col.position.y = _shape.height / 2.0
	_rebuild()


func rotate_prop() -> void:
	disguise_yaw += PI / 4.0
	if prop_node:
		prop_node.rotation.y = disguise_yaw


func set_ghost(on: bool) -> void:
	ghost = on
	disguise = ""
	_col.shape = _shape
	_col.position.y = _shape.height / 2.0
	prop_locked = false
	_rebuild()


func reset_round_state() -> void:
	if hide_spot >= 0:
		exit_spot()
	ghost = false
	disguise = ""
	_col.shape = _shape
	_col.position.y = _shape.height / 2.0
	prop_locked = false
	stun = 0.0
	frozen = false
	crouch = false
	flashlight.visible = false
	_rebuild()


func teleport(pos: Vector3, face_yaw: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	yaw = face_yaw
	pitch = -0.25
	visual.rotation.y = face_yaw
	reset_physics_interpolation()


func look(delta: Vector2) -> void:
	yaw -= delta.x
	pitch = clampf(pitch - delta.y, -1.3, 1.0)


func facing() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func aim_dir() -> Vector3:
	return -cam.global_transform.basis.z


func eye_pos() -> Vector3:
	return cam.global_position if hide_spot >= 0 else global_position + Vector3(0, 1.2, 0)


func is_moving() -> bool:
	return Vector2(velocity.x, velocity.z).length() > 0.3 and hide_spot < 0


func anim_state() -> String:
	if rig == null:
		return ""
	if lying:
		return "lie"
	return rig.current


func hop() -> void:
	_hop = 0.5


func dance() -> void:
	_dance = CharRig.DANCE_LEN
	_dance_yaw = visual.rotation.y


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


var spot_kind := ""
var _saved_dist := 4.0


func enter_spot(index: int, spot: Dictionary) -> void:
	hide_spot = index
	spot_kind = spot.get("kind", "hide")
	_spot_exit = spot["exit"]
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	yaw = spot["yaw"]
	if spot_kind == "car":
		# hidden inside; the camera orbits the car
		global_position = spot["cam"]
		pitch = -0.18
		visual.visible = false
		_saved_dist = cam_dist
		cam_dist = 5.6
	elif spot_kind == "bike":
		# sit on the bike, seen from behind
		global_position = spot["cam"] + Vector3(0, RIDE_HEIGHT, 0)
		visual.rotation.y = yaw
		pitch = -0.2
		visual.visible = true
		if rig:
			rig.play("drive")
	else:
		global_position = spot["cam"] - Vector3(0, 1.35, 0)
		pitch = 0.0
		_arm_len = 0.0
		_shoulder_now = 0.0
		visual.visible = false
	reset_physics_interpolation()


func riding() -> bool:
	return hide_spot >= 0 and spot_kind == "bike"


func in_vehicle() -> bool:
	return hide_spot >= 0 and spot_kind in ["bike", "car"]


func exit_spot() -> void:
	if spot_kind == "car":
		cam_dist = _saved_dist
	hide_spot = -1
	spot_kind = ""
	collision_layer = 2
	collision_mask = 1
	global_position = _spot_exit
	reset_physics_interpolation()
	visual.visible = true


func say(text: String) -> void:
	pop_bubble(bubble, text)
	_bubble_t = 3.0


## Show a speech bubble; a lone emoji pops up big.
static func pop_bubble(b: Label3D, text: String) -> void:
	b.text = text
	b.visible = true
	var emoji := text.length() <= 2
	b.font_size = 150 if emoji else 72
	b.scale = Vector3.ONE * 0.4
	b.create_tween().tween_property(b, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_crouch(on: bool) -> void:
	if on == (_shape.height < STAND_H - 0.01):
		return
	if not on:
		# only stand up if there's room above
		var q := PhysicsShapeQueryParameters3D.new()
		var probe := CapsuleShape3D.new()
		probe.radius = 0.28
		probe.height = STAND_H
		q.shape = probe
		q.transform = Transform3D(Basis(), global_position + Vector3(0, STAND_H / 2.0 + 0.05, 0))
		q.collision_mask = 1
		if not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
			return
	_shape.height = CROUCH_H if on else STAND_H
	_col.position.y = _shape.height / 2.0


func _physics_process(dt: float) -> void:
	if hide_spot >= 0:
		return
	if held:
		# climbing a ladder / walking hand in hand: someone else places us every frame
		velocity = Vector3.ZERO
		return
	if sitting:
		# chill mode: sitting on a sofa; push the stick or jump to get up
		velocity = Vector3.ZERO
		if move_input.length() > 0.4 or jump_req:
			jump_req = false
			stand_up()
		return
	if stun > 0.0:
		stun -= dt
	_set_crouch(crouch and disguise == "")
	var input := move_input
	if frozen or stun > 0.0 or prop_locked:
		input = Vector2.ZERO
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw)
	var crouched := _shape.height < STAND_H - 0.01
	var spd := CROUCH_SPEED if crouched else (RUN if run else SPEED)
	if ghost:
		spd *= 1.25
	if boost > 0.0:
		boost -= dt
		spd *= 1.6
	var target := dir * spd
	var accel := 30.0 if is_on_floor() else 10.0
	velocity.x = move_toward(velocity.x, target.x, accel * dt)
	velocity.z = move_toward(velocity.z, target.z, accel * dt)
	if not is_on_floor():
		velocity.y -= GRAVITY * dt
		_air_t += dt
	else:
		_air_t = 0.0
	if jump_req and is_on_floor() and not frozen and not prop_locked:
		velocity.y = JUMP
		if rig:
			rig.gesture("jump")
	var jumped := jump_req
	jump_req = false
	var fall_speed := -velocity.y
	move_and_slide()
	if is_on_floor() and fall_speed > 1.5:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var o := col.get_collider()
			if o != null and o.has_meta("bouncy") and col.get_normal().y > 0.7:
				# beds: a small bounce that dies out; the trampoline keeps you flying
				var strength: float = o.get_meta("bouncy") if o.get_meta("bouncy") is float else 5.0
				var keep: bool = o.get_meta("sustain", false)
				var vy := minf(strength, fall_speed * (1.08 if keep else 0.7))
				if keep:
					vy = maxf(vy, 9.0)
				if jumped:
					vy = minf(strength, vy + 2.0)
				if vy > 2.2:
					velocity.y = vy
					Sfx.play("boing" if keep else "bedcreak", -3.0, randf_range(0.95, 1.08))
				break
	if dir.length() > 0.1 and not prop_locked:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, dt * 12.0))
	# footsteps
	if is_on_floor() and is_moving() and disguise == "" and not ghost:
		_step_d += Vector2(velocity.x, velocity.z).length() * dt
		var stride := 0.55 if crouched else (1.0 if run else 0.8)
		if _step_d > stride:
			_step_d = 0.0
			Sfx.footstep(house.surface_at(global_position) if house else "wood", -16.0 if crouched else -9.0)


var _cam_y := 0.0
var _out_hold := 0.0
var _up_ray := PhysicsRayQueryParameters3D.new()


## The camera eases after you vertically (no snapping on every hop or landing) and never
## starts inside the ceiling when you're bouncing or standing on furniture.
func _update_pivot_height(dt: float, crouched: bool) -> void:
	var want := global_position.y + (0.95 if crouched else 1.45)
	_up_ray.from = global_position + Vector3(0, 0.4, 0)
	_up_ray.to = Vector3(global_position.x, want + 0.35, global_position.z)
	_up_ray.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(_up_ray)
	if hit:
		want = minf(want, (hit["position"] as Vector3).y - 0.35)
	if absf(_cam_y - want) > 3.0 or hide_spot >= 0:
		_cam_y = want
	elif want < _cam_y:
		_cam_y = lerpf(_cam_y, want, 1.0 - exp(-dt * 22.0))  # duck under ceilings quickly
	else:
		_cam_y = lerpf(_cam_y, want, 1.0 - exp(-dt * 8.0))
	pivot.position.y = _cam_y - global_position.y


## Places the camera behind the player, pulled in smoothly when walls are in the way:
## quick (but not instant) to move in, slow to ease back out, so it never jitters.
func _update_boom(dt: float) -> void:
	if hide_spot >= 0 and not in_vehicle():
		arm.position = Vector3.ZERO
		cam.position = Vector3.ZERO
		return
	var want := cam_dist + (1.2 if disguise != "" else 0.0)
	var space := get_world_3d().direct_space_state
	if house and _cast_q.exclude.is_empty() and not house.camera_ignore.is_empty():
		_cast_q.exclude = house.camera_ignore
	var origin := pivot.global_position
	var basis := pivot.global_transform.basis
	# one sphere cast from your head straight to where the camera wants to be
	# (over the shoulder and behind); the shoulder shrinks together with the arm
	var full := Vector3(shoulder, 0, want)
	_cast_q.transform = Transform3D(Basis(), origin)
	_cast_q.motion = basis * full
	var free: float = space.cast_motion(_cast_q)[0]
	var target := want * free
	if target < _arm_len:
		# something is in the way: jump in right away (never sit inside a wall)
		_arm_len = target
		_out_hold = 0.35
	else:
		# space opened up: wait a moment, then ease back out slowly (no flicker at corners)
		_out_hold -= dt
		if _out_hold <= 0.0:
			_arm_len = lerpf(_arm_len, target, 1.0 - exp(-dt * 2.5))
	_shoulder_now = shoulder * (_arm_len / want if want > 0.0 else 0.0)
	arm.position = Vector3(_shoulder_now, 0, 0)
	cam.position = Vector3(0, 0, _arm_len)


func _process(dt: float) -> void:
	pivot.rotation = Vector3(pitch, yaw, 0)
	_probe_t -= dt
	if _probe_t <= 0.0 and house and not no_probe:
		_probe_t = 0.12
		var c := house.light_at(global_position + Vector3(0, 0.9, 0))
		if rig:
			rig.set_light(c)
		Kit.set_probe_light(_prop_mats, c)
	var crouched := _shape.height < STAND_H - 0.01
	_update_pivot_height(dt, crouched)
	if not no_boom:
		_update_boom(dt)
	# don't let your own body fill the screen when the camera is squeezed against a wall
	if hide_spot < 0 or riding():
		visual.visible = cam.global_position.distance_to(pivot.global_position) > 1.0
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - dt * 2.5)
		cam.h_offset = randf_range(-1, 1) * _shake * 0.25
		cam.v_offset = randf_range(-1, 1) * _shake * 0.25
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	if _hop > 0.0:
		_hop -= dt
		visual.position.y = sin((0.5 - _hop) / 0.5 * PI) * 0.45
		visual.rotation.z = sin(_hop * 40.0) * 0.12
	elif _dance > 0.0:
		_dance -= dt
		if rig:
			rig.dance_tick(CharRig.DANCE_LEN - maxf(_dance, 0.0), _dance_yaw, visual)
		else:
			visual.position.y = absf(sin(_dance * 9.0)) * 0.3
			visual.rotation.y += dt * 9.0
	else:
		visual.position.y = 0.0
		visual.rotation.z = 0.0
	if rig != null and riding():
		rig.play("drive")
	elif rig != null:
		if stun > 0.0:
			rig.rotation.y += dt * 16.0
		else:
			rig.rotation.y = 0.0
		if not rig.busy() or is_moving():
			var hs := Vector2(velocity.x, velocity.z).length()
			if not is_on_floor() and _air_t > 0.25:
				rig.play("fall")
			elif crouched:
				rig.play("crouch", 1.0 if hs > 0.2 else 0.0)
			elif hs > 4.8:
				rig.play("sprint", 1.0)
			elif hs > 0.25:
				rig.play("walk", clampf(hs / 3.0, 0.8, 1.4))
			elif anim_hold != "":
				rig.play(anim_hold, 0.6 if anim_hold == "holding-both" else 1.0)
			else:
				rig.play("idle")
	if _bubble_t > 0.0:
		_bubble_t -= dt
		bubble.modulate.a = clampf(_bubble_t * 2.0, 0.0, 1.0)
		if _bubble_t <= 0.0:
			bubble.visible = false
