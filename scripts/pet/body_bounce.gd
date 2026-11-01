class_name BodyBounce
extends SkeletonModifier3D
## Springy squash & stretch and a side-to-side wobble on the root bone. The root
## sits at the feet, so the pet squashes into the floor. Layers over animation.

const SQUASH_OMEGA := 19.0
const SQUASH_DAMPING := 0.4
## Velocity kick per unit of peak squash, for the spring above.
const SQUASH_KICK := 40.0
const MAX_SQUASH := 0.22
const WOBBLE_OMEGA := 15.0
const WOBBLE_DAMPING := 0.15
const WOBBLE_KICK := 18.5
## Keeps the explicit spring step stable through a frame hitch.
const MAX_STEP := 1.0 / 30.0

var _root := -1
## (amount, velocity); a positive amount is shorter and wider.
var _squash := Vector2.ZERO
## (roll radians, velocity).
var _wobble := Vector2.ZERO
var _wobble_side := 1.0


func setup(root: int) -> void:
	_root = root


## amount: roughly the peak squash, 0.1 = 10 % shorter. Overshoots into a stretch.
func squash(amount: float) -> void:
	_squash.y = minf(_squash.y + amount * SQUASH_KICK, MAX_SQUASH * SQUASH_KICK)


## amount: roughly the first roll, in radians. Alternates sides.
func wobble(amount: float) -> void:
	_wobble_side = -_wobble_side
	_wobble.y += amount * WOBBLE_KICK * _wobble_side


## One semi-implicit step of a damped spring at rest position 0.
static func step(state: Vector2, omega: float, damping: float, delta: float) -> Vector2:
	var velocity := state.y - (omega * omega * state.x + 2.0 * damping * omega * state.y) * delta
	return Vector2(state.x + velocity * delta, velocity)


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _root < 0:
		return
	var dt := minf(delta, MAX_STEP)
	_squash = step(_squash, SQUASH_OMEGA, SQUASH_DAMPING, dt)
	_wobble = step(_wobble, WOBBLE_OMEGA, WOBBLE_DAMPING, dt)
	if _squash.is_zero_approx() and _wobble.is_zero_approx():
		return
	var s := _squash.x
	skeleton.set_bone_pose_scale(_root, skeleton.get_bone_pose_scale(_root) * Vector3(1.0 + s * 0.5, 1.0 - s, 1.0 + s * 0.5))
	skeleton.set_bone_pose_rotation(_root, Quaternion(Vector3.BACK, _wobble.x) * skeleton.get_bone_pose_rotation(_root))
