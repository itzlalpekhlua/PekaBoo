class_name PoseMod
extends SkeletonModifier3D
## Leans the body, tilts the head and moves the arms on top of whatever animation is playing
## (kiss, hug, slow dance, cuddling on the sofa, dancing). The base pose eases towards its
## target; "live" values are set every frame by whoever is animating (sways, raised arms).

var lean := 0.0          # radians, torso forward
var roll := 0.0          # radians, torso to the side
var tilt := 0.0          # radians, head to the side
var nod := 0.0           # radians, head forward
var arms := 0.0          # 0..1 arms wrap around (hug)
var target := {"lean": 0.0, "roll": 0.0, "tilt": 0.0, "nod": 0.0, "arms": 0.0}
var live := {"lean": 0.0, "roll": 0.0, "arm_l": 0.0, "arm_r": 0.0}
var _torso := -1
var _head := -1
var _arm_l := -1
var _arm_r := -1


func _ready() -> void:
	var sk := get_skeleton()
	if sk:
		_torso = sk.find_bone("torso")
		_head = sk.find_bone("head")
		_arm_l = sk.find_bone("arm-left")
		_arm_r = sk.find_bone("arm-right")


func set_pose(l: float, t: float, n: float, a: float, r := 0.0) -> void:
	target = {"lean": l, "roll": r, "tilt": t, "nod": n, "arms": a}


func clear_live() -> void:
	live = {"lean": 0.0, "roll": 0.0, "arm_l": 0.0, "arm_r": 0.0}


func _process(dt: float) -> void:
	var k := 1.0 - exp(-dt * 5.0)
	lean = lerpf(lean, target["lean"], k)
	roll = lerpf(roll, target["roll"], k)
	tilt = lerpf(tilt, target["tilt"], k)
	nod = lerpf(nod, target["nod"], k)
	arms = lerpf(arms, target["arms"], k)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var l: float = lean + live["lean"]
	var r: float = roll + live["roll"]
	var al: float = live["arm_l"]
	var ar: float = live["arm_r"]
	if (absf(l) + absf(r) + absf(tilt) + absf(nod) + absf(arms) + absf(al) + absf(ar)) < 0.001:
		return
	if _torso >= 0:
		sk.set_bone_pose_rotation(_torso, sk.get_bone_pose_rotation(_torso) * Quaternion(Vector3.RIGHT, l) * Quaternion(Vector3.FORWARD, r))
	if _head >= 0:
		sk.set_bone_pose_rotation(_head, sk.get_bone_pose_rotation(_head) * Quaternion(Vector3.RIGHT, nod) * Quaternion(Vector3.FORWARD, tilt))
	# arms: wrap forward and inwards (hug), plus raise (al / ar, radians forward-up)
	if _arm_l >= 0 and (arms > 0.001 or absf(al) > 0.001):
		sk.set_bone_pose_rotation(_arm_l, sk.get_bone_pose_rotation(_arm_l) * Quaternion(Vector3.RIGHT, arms * 1.25 + al) * Quaternion(Vector3.UP, arms * 0.6))
	if _arm_r >= 0 and (arms > 0.001 or absf(ar) > 0.001):
		sk.set_bone_pose_rotation(_arm_r, sk.get_bone_pose_rotation(_arm_r) * Quaternion(Vector3.RIGHT, arms * 1.25 + ar) * Quaternion(Vector3.UP, -arms * 0.6))
