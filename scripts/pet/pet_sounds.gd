class_name PetSounds
extends RefCounted
## Each pet's body and animal sounds, by clip or event. A sound is an AudioDirector
## name (a name with takes, like &"pad" = pad_1..4, plays one of them), or a table
## of names per pet. Zone, greeting and toy-finale sounds are in PetReactions and
## ToyScript; prop sounds (pops, pours, bounces) are played by ToySession.

const RUN := &"run"
## The excited hops when a toy arrives: the dog pants, the bunny thumps.
const EXCITED := {&"cat": &"chirp", &"dog": &"pant", &"bunny": &"thump"}
## Clip → [seconds into the clip, sound] cues, timed to the GLB actions
## (tools/blender/build_pets.py). Pet plays them as each clip starts.
const CLIPS := {
	&"sit_down": [[0.35, &"sit"]],
	&"lie_down": [[0.4, &"lie"]],
	&"get_up": [[0.1, &"rollover"]],
	&"jump": [[0.1, &"jump"], [0.4, &"land"]],
	&"pounce": [[0.25, &"pounce"]],
	&"laugh_tumble": [[0.25, &"tumble"], [1.45, &"rollover"]],
	&"happy_wiggle": [[0.1, &"wiggle"], [0.4, &"swish"]],
	&"scratch_ear": [[0.3, &"scratch"], [0.95, &"flap"]],
	&"head_shake": [[0.08, &"flap"]],
	&"excited": [[0.1, EXCITED]],
}
## Walk-in steps.
const STEPS := {&"cat": &"pad", &"dog": &"step", &"bunny": &"hop"}
## Toy-session bites and laps (a toy may name its own bite sound).
const EAT := {&"cat": &"nibble", &"dog": &"gnaw", &"bunny": &"crunch"}
const DRINK := {&"cat": &"lap", &"dog": &"lap", &"bunny": &"sip"}
## A short call after the child's echo, under it.
const ECHO_CALL := {&"cat": &"chirp", &"dog": &"yip", &"bunny": &"squeak"}
## Purr-like contentment, a loop on Loops; the cat's ends with its tail clip.
const PURR := {&"cat": &"purr_loop", &"bunny": &"purr_bunny"}
const PURR_TAIL := {&"cat": &"purr_tail"}
## Rare idle surprises (PetIdle.surprise), each with a little squash.
const SURPRISES: Array[StringName] = [&"sneeze", &"hiccup"]


## The sound for this pet: the name itself, or its entry in a per-pet table (&"" for none).
static func pick(sound: Variant, pet_id: StringName) -> StringName:
	if sound is Dictionary:
		return (sound as Dictionary).get(pet_id, &"")
	return sound
