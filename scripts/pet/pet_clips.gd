class_name PetClips
extends RefCounted
## Plays reaction clips on the pet's AnimationPlayer: stand-ins for clips a GLB
## lacks, the blend times, and a "retake" copy of every clip so the same clip
## tapped again mid-play blends into a fresh take instead of snapping to frame 0.

const IDLE := &"idle_breathe"
const WALK := &"walk_in"
const BLEND_SEC := 0.2
const REACT_BLEND_SEC := 0.12
const IDLE_BLEND_SEC := 0.3
const RETAKE := "_retake"
## Stand-ins for clips the GLBs may not have yet.
const FALLBACKS := {
	&"happy_wiggle": &"happy_bounce",
	&"laugh_tumble": &"happy_bounce",
	&"wave": &"happy_bounce",
}

var _player: AnimationPlayer
var _retakes := {}


func _init(player: AnimationPlayer) -> void:
	_player = player
	_player.playback_default_blend_time = BLEND_SEC
	var library := _player.get_animation_library(&"")
	for clip in _player.get_animation_list():
		if clip == IDLE or clip == WALK or clip.ends_with(RETAKE):
			continue
		var retake := StringName(clip + RETAKE)
		if not library.has_animation(retake):
			library.add_animation(retake, library.get_animation(clip))
		_retakes[StringName(clip)] = retake
		_retakes[retake] = StringName(clip)
		_player.set_blend_time(clip, IDLE, IDLE_BLEND_SEC)
		_player.set_blend_time(retake, IDLE, IDLE_BLEND_SEC)


## The clip, its stand-in while the GLB lacks it, or &"" for neither.
func resolve(clip: StringName) -> StringName:
	if _player.has_animation(clip):
		return clip
	var stand_in: StringName = FALLBACKS.get(clip, &"")
	return stand_in if _player.has_animation(stand_in) else &""


## One-clip variants for the clips the GLB really has (no stand-ins, so a
## stand-in never repeats a real clip in the same picker).
func variants_of(clips: Array[StringName]) -> Array:
	var variants := []
	for clip in clips:
		if _player.has_animation(clip):
			variants.append([clip])
	return variants


## Plays the clips in order, then idle. Returns their total length, 0 if none exist.
func play(clips: Array) -> float:
	var first := resolve(clips[0])
	if first == &"":
		return 0.0
	if _player.current_animation == first:
		first = _retakes.get(first, first)
	_player.clear_queue()
	_player.play(first, REACT_BLEND_SEC)
	var length := _player.get_animation(first).length
	for i in range(1, clips.size()):
		var clip := resolve(clips[i])
		if clip != &"":
			_player.queue(clip)
			length += _player.get_animation(clip).length
	_player.queue(IDLE)
	return length
