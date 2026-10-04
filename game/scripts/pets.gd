class_name Pets
extends Node3D
## A cat (Mochi) and a dog (Biscuit) who live in the house. They wander about, follow whoever is
## nearby for a while, and love being petted. The host decides where they go and tells the other
## phone a few times a second; the other phone just glides them along.

const NAMES := ["Mochi", "Biscuit"]
var main: Node
var house: House
var active := false
var pets: Array = []      # {node, legs, tail, head, kind, pos, target, yaw, wait, happy, follow, net_pos, net_yaw}
var _send_t := 0.0


func setup(m: Node, h: House) -> void:
	main = m
	house = h
	pets.append(_make("cat", Vector3(6.0, 0.0, 13.8)))
	pets.append(_make("dog", Vector3(13.0, 0.0, 20.0)))
	visible = false


func _make(kind: String, at: Vector3) -> Dictionary:
	var n := Node3D.new()
	add_child(n)
	var body := Node3D.new()
	n.add_child(body)
	var cat := kind == "cat"
	var fur := Color("#f3a65a") if cat else Color("#b07a4c")
	var light := Color("#fff4e6") if cat else Color("#f0d9b8")
	var s := 0.85 if cat else 1.1
	body.scale = Vector3.ONE * s
	Build.cube(body, Vector3(0.28, 0.2, 0.46), Vector3(0, 0.28, 0), fur)
	Build.cube(body, Vector3(0.22, 0.05, 0.36), Vector3(0, 0.17, 0), light)
	var head := Node3D.new()
	head.position = Vector3(0, 0.44, -0.28)
	body.add_child(head)
	Build.cube(head, Vector3(0.3, 0.26, 0.26), Vector3.ZERO, fur)
	Build.cube(head, Vector3(0.16, 0.1, 0.06), Vector3(0, -0.05, -0.14), light)
	Build.cube(head, Vector3(0.05, 0.035, 0.02), Vector3(0, -0.015, -0.175), Color("#3a2a2a"))
	for sx in [-0.075, 0.075]:
		Build.cube(head, Vector3(0.045, 0.06, 0.02), Vector3(sx, 0.04, -0.135), Color("#1d1824"))
		Build.cube(head, Vector3(0.016, 0.02, 0.01), Vector3(sx + 0.012, 0.055, -0.147), Color.WHITE)
		if cat:
			var ear := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.1, 0.11, 0.06)
			ear.mesh = pm
			ear.material_override = Build.mat(fur)
			ear.position = Vector3(sx * 1.4, 0.18, 0.0)
			head.add_child(ear)
		else:
			Build.cube(head, Vector3(0.06, 0.16, 0.08), Vector3(sx * 2.1, 0.02, 0.02), Color("#7d5233"))
	if not cat:
		Build.cube(head, Vector3(0.05, 0.02, 0.05), Vector3(0.0, -0.11, -0.16), Color("#ff7a9a"))
	var legs := []
	for lx in [-0.09, 0.09]:
		for lz in [-0.15, 0.15]:
			var leg := Node3D.new()
			leg.position = Vector3(lx, 0.2, lz)
			body.add_child(leg)
			Build.cube(leg, Vector3(0.07, 0.2, 0.07), Vector3(0, -0.1, 0), fur)
			legs.append(leg)
	var tail := Node3D.new()
	tail.position = Vector3(0, 0.33, 0.23)
	body.add_child(tail)
	Build.cube(tail, Vector3(0.05, 0.05, 0.26 if cat else 0.16), Vector3(0, 0.06, 0.1), fur)
	tail.rotation.x = -0.7
	_merge_parts(body)
	_merge_parts(head)
	var mats := Kit.apply_probe_look(n, 0.5)
	n.position = at
	return {"node": n, "body": body, "legs": legs, "tail": tail, "head": head, "kind": kind, "mats": mats,
		"target": at, "yaw": 0.0, "wait": randf_range(1.0, 4.0), "happy": 0.0, "follow": -1, "follow_t": 0.0,
		"net_pos": at, "net_yaw": 0.0, "walk": 0.0, "light_t": 0.0}


## The pets are made of many little boxes; join the ones on the same part and with the same
## colour into one mesh, so the phone draws a handful of pieces instead of ~25.
func _merge_parts(parent: Node3D) -> void:
	var groups := {}
	for c in parent.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			var mi := c as MeshInstance3D
			var mat: Material = mi.material_override if mi.material_override else mi.get_active_material(0)
			var key := str(mat.get_instance_id())
			if not groups.has(key):
				groups[key] = {"mat": mat, "items": []}
			groups[key]["items"].append(mi)
	for key in groups:
		var items: Array = groups[key]["items"]
		if items.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi in items:
			st.append_from((mi as MeshInstance3D).mesh, 0, (mi as MeshInstance3D).transform)
		var merged := MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = groups[key]["mat"]
		parent.add_child(merged)
		for mi in items:
			(mi as Node).queue_free()
			parent.remove_child(mi)


func _process(dt: float) -> void:
	visible = active
	if not active:
		return
	var leader: bool = not Net.is_online() or Net.is_host()
	for i in pets.size():
		var p: Dictionary = pets[i]
		var n: Node3D = p["node"]
		var before := n.global_position
		if leader:
			_think(p, dt)
		else:
			n.global_position = n.global_position.lerp(p["net_pos"], 1.0 - exp(-8.0 * dt))
			n.rotation.y = lerp_angle(n.rotation.y, p["net_yaw"], 1.0 - exp(-8.0 * dt))
		_animate(p, dt, before.distance_to(n.global_position) / maxf(dt, 0.001))
		p["light_t"] -= dt
		if p["light_t"] <= 0.0:
			p["light_t"] = 0.25
			Kit.set_probe_light(p["mats"], house.light_at(n.global_position + Vector3(0, 0.5, 0)))
	if leader and Net.is_online():
		_send_t -= dt
		if _send_t <= 0.0:
			_send_t = 0.2
			var st := []
			for p in pets:
				var q: Vector3 = (p["node"] as Node3D).global_position
				st.append([snappedf(q.x, 0.01), snappedf(q.y, 0.01), snappedf(q.z, 0.01), snappedf((p["node"] as Node3D).rotation.y, 0.01), snappedf(p["happy"], 0.1)])
			main._fx({"k": "pets", "p": st})


## Wander around the ground floor / garden; sometimes tag along behind someone.
func _think(p: Dictionary, dt: float) -> void:
	var n: Node3D = p["node"]
	p["happy"] = maxf(0.0, p["happy"] - dt)
	if p["happy"] > 0.0:
		return
	var target: Vector3 = p["target"]
	if p["follow_t"] > 0.0:
		p["follow_t"] -= dt
		var who: Node3D = main._actor(p["follow"])
		if who != null and who.global_position.y < 1.0:
			var to := who.global_position - n.global_position
			to.y = 0.0
			if to.length() > 1.4:
				target = who.global_position - to.normalized() * 1.1
			else:
				target = n.global_position
	var to := target - n.global_position
	to.y = 0.0
	if to.length() < 0.2:
		p["wait"] -= dt
		if p["wait"] <= 0.0:
			p["wait"] = randf_range(2.0, 6.0)
			if randf() < 0.35 and p["follow_t"] <= 0.0:
				var ids: Array = Net.players.keys() if Net.is_online() else [Net.my_id]
				p["follow"] = ids[randi() % ids.size()]
				p["follow_t"] = randf_range(10.0, 20.0)
			else:
				p["target"] = _random_spot(p["kind"])
		return
	var speed := (1.3 if p["kind"] == "cat" else 1.7) * (1.4 if p["follow_t"] > 0.0 else 1.0)
	var step := to.normalized() * minf(speed * dt, to.length())
	var next := n.global_position + step
	# don't walk through walls: if blocked, pick somewhere else
	var q := PhysicsRayQueryParameters3D.create(n.global_position + Vector3(0, 0.3, 0), next + Vector3(0, 0.3, 0) + step.normalized() * 0.3, 1)
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		p["target"] = _random_spot(p["kind"])
		p["follow_t"] = 0.0
		return
	next.y = 0.0
	n.global_position = next
	n.rotation.y = lerp_angle(n.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-10.0 * dt))


func _random_spot(kind: String) -> Vector3:
	var rooms := [Vector3(5, 0, 12), Vector3(15, 0, 11), Vector3(12, 0, 7), Vector3(11.5, 0, 3), Vector3(8, 0, 20), Vector3(14, 0, 24), Vector3(20, 0, 19)]
	if kind == "cat":
		rooms = rooms.slice(0, 5)
	var c: Vector3 = rooms[randi() % rooms.size()]
	return c + Vector3(randf_range(-2.0, 2.0), 0, randf_range(-1.5, 1.5))


func _animate(p: Dictionary, dt: float, speed: float) -> void:
	var walking := speed > 0.2
	p["walk"] += dt * (11.0 if walking else 0.0)
	var w: float = p["walk"]
	var legs: Array = p["legs"]
	for k in legs.size():
		(legs[k] as Node3D).rotation.x = sin(w + (PI if k % 3 == 0 else 0.0)) * (0.6 if walking else 0.0)
	var t := Time.get_ticks_msec() / 1000.0
	var tail: Node3D = p["tail"]
	var happy: float = p["happy"]
	tail.rotation.y = sin(t * (14.0 if happy > 0.0 or p["kind"] == "dog" else 3.0)) * (0.7 if happy > 0.0 else 0.35)
	var body: Node3D = p["body"]
	body.position.y = absf(sin(t * 10.0)) * 0.12 if happy > 0.0 else 0.0
	(p["head"] as Node3D).rotation.x = sin(t * 2.0) * 0.08


## Index of a pet within reach of pos, or -1.
func near(pos: Vector3) -> int:
	if not active:
		return -1
	for i in pets.size():
		var q: Vector3 = (pets[i]["node"] as Node3D).global_position
		if Vector2(q.x - pos.x, q.z - pos.z).length() < 1.3 and absf(q.y - pos.y) < 1.0:
			return i
	return -1


func pet(i: int) -> void:
	if i < 0 or i >= pets.size():
		return
	var p: Dictionary = pets[i]
	p["happy"] = 2.5
	var at := (p["node"] as Node3D).global_position
	Build.burst(main, at - Vector3(0, 0.6, 0), "hearts")
	Sfx.play_at("meow" if p["kind"] == "cat" else "woof", at + Vector3(0, 0.4, 0), 2.0)
	main.ui.toast("%s loves you! 🐾" % NAMES[i], 1.8)


func apply_state(st: Array) -> void:
	for i in mini(st.size(), pets.size()):
		var s: Array = st[i]
		pets[i]["net_pos"] = Vector3(float(s[0]), float(s[1]), float(s[2]))
		pets[i]["net_yaw"] = float(s[3])
		pets[i]["happy"] = float(s[4])
