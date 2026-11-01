class_name HeadLook
extends SkeletonModifier3D
## Turns the head, and a little of the chest, toward what the pet is watching: a
## finger while one is down, a toy for a moment, otherwise the camera with a slow
## wander. Also layers the listen tilt, the talk bob, a lean, ear flicks and a
## micro-sway. All of it is added on top of the AnimationPlayer's pose, so nods
## and reactions still show through.

const MAX_YAW := deg_to_rad(28.0)
const MAX_PITCH := deg_to_rad(16.0)
## Critically damped, in rad/s: trails a moving finger by about 0.3 s.
const FOLLOW_OMEGA := 6.0
const POSE_OMEGA := 7.0
## Share of the turn the chest takes; the head does the rest.
const CHEST_SHARE := 0.25
## A released finger stays watched this long, so a quick tap still gets a glance.
const LINGER_SEC := 0.6
const WANDER_YAW := deg_to_rad(7.0)
const WANDER_PITCH := deg_to_rad(3.0)
const SWAY := deg_to_rad(1.5)
const LISTEN_TILT := deg_to_rad(13.0)
const LISTEN_LEAN := deg_to_rad(4.0)
const STROKE_LEAN := deg_to_rad(6.0)
const STROKE_TILT := deg_to_rad(10.0)
## Finger this far (m) to the side of the face gives the full stroke tilt.
const STROKE_SIDE_M := 0.15
const TALK_BOB := deg_to_rad(5.0)
const TALK_LAG_SEC := 0.06
const FLICK_SEC := 0.2

## Mouth opening 0..1; bobs the head while `talking`.
var talk := 0.0
var talking := false
var stroking := false

var _chest := -1
var _head := -1
var _eye := Vector3.ZERO
var _ears := PackedInt32Array()
var _ear_axes: Array[Vector3] = []
var _ear_angles := PackedFloat32Array()
var _flick_left := PackedFloat32Array()
var _flick_wait := 0.0

var _target := Vector3.ZERO
var _following := false
var _hold_left := 0.0
var _listening := false
var _tilt_side := 1.0
var _wander := Vector2.ZERO
var _wander_left := 0.0
## Spring states, (value, velocity).
var _yaw := Vector2.ZERO
var _pitch := Vector2.ZERO
var _tilt := Vector2.ZERO
var _lean := Vector2.ZERO
var _bob := 0.0
var _talk_weight := 0.0
var _time := 0.0
var _phases := Vector4.ZERO
var _rng := RandomNumberGenerator.new()


## eye: point between the eyes at rest, in skeleton space; the look aims from here.
func setup(chest: int, head: int, eye: Vector3) -> void:
	_chest = chest
	_head = head
	_eye = eye
	_rng.randomize()
	_phases = Vector4(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)


## axis/angle in skeleton space: the ear's flick at full swing.
func add_ear(bone: int, axis: Vector3, angle: float) -> void:
	_ears.append(bone)
	_ear_axes.append(axis.normalized())
	_ear_angles.append(angle)
	_flick_left.append(0.0)


## A finger is down at this world point.
func follow(point: Vector3) -> void:
	_target = point
	_following = true


func release() -> void:
	if _following:
		_following = false
		_hold_left = LINGER_SEC


## Looks at a world point for a moment (a toy), unless a finger is down.
func glance(point: Vector3, seconds: float) -> void:
	if _following:
		return
	_target = point
	_hold_left = seconds


## Straight eye contact with the camera for a while.
func focus(seconds: float) -> void:
	_hold_left = 0.0
	_wander = Vector2.ZERO
	_wander_left = seconds


## Each new listen tilts the head to the other side.
func set_listening(on: bool) -> void:
	if on and not _listening:
		_tilt_side = -_tilt_side
	_listening = on


## Exact critically damped step toward target; state is (value, velocity).
static func spring(state: Vector2, target: float, omega: float, delta: float) -> Vector2:
	var x := state.x - target
	var j := (state.y + omega * x) * delta
	var decay := exp(-omega * delta)
	return Vector2(target + (x + j) * decay, (state.y - omega * j) * decay)


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	var camera := get_viewport().get_camera_3d()
	if skeleton == null or camera == null or _head < 0:
		return
	_time += delta
	_hold_left -= delta
	var to_skeleton := skeleton.global_transform.affine_inverse()
	var to_camera := to_skeleton * camera.global_position - _eye
	var watching := _following or _hold_left > 0.0
	var to_target := to_skeleton * _target - _eye if watching else to_camera
	var yaw := atan2(to_target.x, to_target.z)
	var pitch := atan2(to_target.y, Vector2(to_target.x, to_target.z).length())
	if not watching:
		_update_wander(delta)
		yaw += _wander.x
		pitch += _wander.y
	_yaw = spring(_yaw, clampf(yaw, -MAX_YAW, MAX_YAW), FOLLOW_OMEGA, delta)
	_pitch = spring(_pitch, clampf(pitch, -MAX_PITCH, MAX_PITCH), FOLLOW_OMEGA, delta)

	var tilt := LISTEN_TILT * _tilt_side if _listening else 0.0
	var lean := LISTEN_LEAN if _listening else 0.0
	if stroking and watching:
		# Rub the cheek into the finger: tilt toward the side it is on, seen from the camera.
		var side := (to_target.x * to_camera.z - to_target.z * to_camera.x) / maxf(Vector2(to_camera.x, to_camera.z).length(), 0.01)
		tilt = -clampf(side / STROKE_SIDE_M, -1.0, 1.0) * STROKE_TILT
		lean += STROKE_LEAN
	_tilt = spring(_tilt, tilt, POSE_OMEGA, delta)
	_lean = spring(_lean, lean, POSE_OMEGA, delta)
	_bob = lerpf(_bob, talk, 1.0 - exp(-delta / TALK_LAG_SEC))
	_talk_weight = move_toward(_talk_weight, 1.0 if talking else 0.0, delta * 6.0)
	var nod := (_bob * 2.0 - 1.0) * TALK_BOB * _talk_weight

	var sway_a := (sin(_time * 1.9 + _phases.x) * 0.6 + sin(_time * 1.13 + _phases.y) * 0.4) * SWAY
	var sway_b := (sin(_time * 1.37 + _phases.z) * 0.6 + sin(_time * 0.71 + _phases.w) * 0.4) * SWAY
	# Lean the way the head is looking: at the camera, or into the finger.
	var lean_axis := Vector3(cos(_yaw.x), 0.0, -sin(_yaw.x))
	_turn(skeleton, _chest, Basis(lean_axis, _lean.x) * Basis(Vector3.UP, _yaw.x * CHEST_SHARE + sway_b) * Basis(Vector3.BACK, sway_a))
	_turn(skeleton, _head, Basis(Vector3.UP, _yaw.x * (1.0 - CHEST_SHARE)) \
			* Basis(Vector3.RIGHT, sway_a - _pitch.x - nod) * Basis(Vector3.BACK, _tilt.x + sway_b))
	_flick_ears(skeleton, delta)


func _update_wander(delta: float) -> void:
	_wander_left -= delta
	if _wander_left > 0.0:
		return
	_wander_left = _rng.randf_range(1.5, 4.0)
	if _rng.randf() < 0.35:
		_wander = Vector2.ZERO
	else:
		_wander = Vector2(_rng.randf_range(-WANDER_YAW, WANDER_YAW), _rng.randf_range(-WANDER_PITCH, WANDER_PITCH))


func _flick_ears(skeleton: Skeleton3D, delta: float) -> void:
	if _ears.is_empty():
		return
	if talking:
		_flick_wait -= delta
		if _flick_wait <= 0.0:
			_flick_wait = _rng.randf_range(0.5, 1.3)
			_flick_left[_rng.randi() % _ears.size()] = FLICK_SEC
	for i in _ears.size():
		if _flick_left[i] <= 0.0:
			continue
		_flick_left[i] -= delta
		var swing := sin(PI * clampf(1.0 - _flick_left[i] / FLICK_SEC, 0.0, 1.0))
		_turn(skeleton, _ears[i], Basis(_ear_axes[i], _ear_angles[i] * swing))


## Rotates a bone about its own origin by `turn`, given in skeleton space.
func _turn(skeleton: Skeleton3D, bone: int, turn: Basis) -> void:
	var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone)).basis
	var pose := skeleton.get_bone_global_pose(bone).basis
	skeleton.set_bone_pose_rotation(bone, (parent.inverse() * turn * pose).get_rotation_quaternion())
