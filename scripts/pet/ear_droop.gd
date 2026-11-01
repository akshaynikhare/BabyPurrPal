class_name EarDroop
extends SkeletonModifier3D
## Tilts the ear bones on top of whatever the AnimationPlayer posed, so "can't
## hear" sadness layers over idle and reactions. Fade it with `influence`.

var _bones := PackedInt32Array()
var _rotations: Array[Basis] = []


## axis/angle are in skeleton space; one entry per bone.
func add_bone(bone: int, axis: Vector3, angle: float) -> void:
	_bones.append(bone)
	_rotations.append(Basis(axis.normalized(), angle))


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for i in _bones.size():
		var bone := _bones[i]
		var parent_pose := skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone))
		var pose := skeleton.get_bone_global_pose(bone)
		var turned := Transform3D(_rotations[i] * pose.basis, pose.origin)
		skeleton.set_bone_pose_rotation(bone, (parent_pose.affine_inverse() * turned).basis.get_rotation_quaternion())
