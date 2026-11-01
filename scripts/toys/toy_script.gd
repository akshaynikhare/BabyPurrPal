class_name ToyScript
extends RefCounted
## Toy sessions as data: per toy, the steps the pet and its prop go through.
## A step plays `clip` (or `stand_in` while the GLB lacks it), fires `cue` as it
## starts and `beat` at each fraction in `beats` of its span, then waits `hold`.
## The span is the clip's length, or `sec` when that is longer: a step without a
## clip, or a short stand-in, which then plays again on every beat. `side` is
## where a paw bat sends the toy: -1 toward the pet's right, +1 its left.
## Per toy: hold (prop origin from the mouth, pet space), tilt (toward the mouth,
## about the pet's x), drain_to (liquid left), end_sfx (with the mood finale).

const POP_SEC := 0.35
## Prop stages run 0 (whole) to 3 (eaten).
const LAST_STAGE := 3
## A bite snaps about 60 % into the clip.
const SNAP: Array[float] = [0.6]
const LAPS: Array[float] = [0.125, 0.375, 0.625, 0.875]
const CHEWS: Array[float] = [0.2, 0.5, 0.8]
## The swiping paw meets the toy a little before the clip's middle.
const CONTACT: Array[float] = [0.45]
## Clips every pet GLB has had from the start; anything else needs one of them as stand-in.
const BASE_CLIPS: Array[StringName] = [&"happy_bounce", &"giggle", &"listen_nod", &"ear_perk", &"paw_highfive_L", &"paw_highfive_R"]

const _BITE := {clip = &"bite", stand_in = &"happy_bounce", sec = 0.5, beats = SNAP, beat = &"bite"}
const _NIBBLE := {clip = &"lap", stand_in = &"listen_nod", sec = 1.6, beats = LAPS, beat = &"nibble"}
const _SNIFF := {clip = &"sniff", stand_in = &"listen_nod", sec = 0.6, cue = &"sniff"}
const _CHEW_LAST := {clip = &"chew", stand_in = &"happy_bounce", sec = 0.8, cue = &"pop_out", beats = [0.5], beat = &"munch"}
const _CHEW_BONE := {clip = &"chew", stand_in = &"happy_bounce", sec = 0.8, beats = CHEWS, beat = &"chew"}
const _POP_IN := {cue = &"pop_floor", sec = POP_SEC}
const _POP_OUT := {cue = &"pop_out", sec = POP_SEC}

const TOYS := {
	&"milk": {
		hold = Vector3(0.0, -0.15, 0.13), tilt = deg_to_rad(-35.0), drain_to = 0.02, end_sfx = [&"yum"],
		steps = [
			_POP_IN,
			{cue = &"lift", sec = 0.5},
			{clip = &"drink", stand_in = &"listen_nod", sec = 2.0, beats = [0.2, 0.5, 0.8], beat = &"gulp"},
			{cue = &"lower", sec = 0.45},
			_POP_OUT,
			{clip = &"ear_perk", cue = &"finale"},
		],
	},
	&"water": {
		drain_to = 0.3, end_sfx = [&"pant"],
		steps = [
			_POP_IN,
			{clip = &"lap", stand_in = &"listen_nod", sec = 1.6, beats = LAPS, beat = &"lap"},
			_POP_OUT,
			{clip = &"happy_bounce", cue = &"finale"},
		],
	},
	&"fish": {
		hold = Vector3(0.0, -0.04, 0.09), end_sfx = [&"yum"],
		steps = [
			{cue = &"pop_hover", sec = POP_SEC},
			_BITE, _BITE, _BITE,
			_CHEW_LAST,
			{clip = &"giggle", cue = &"finale"},
		],
	},
	&"carrot": {
		hold = Vector3(0.0, -0.07, 0.105), tilt = deg_to_rad(-46.0), end_sfx = [&"yum"],
		steps = [
			{cue = &"pop_hover", sec = POP_SEC},
			_BITE, _BITE, _BITE,
			_CHEW_LAST,
			{clip = &"happy_bounce", cue = &"finale"},
		],
	},
	&"clover": {
		end_sfx = [&"yum"],
		steps = [
			_POP_IN,
			_SNIFF,
			_NIBBLE,
			_POP_OUT,
			{clip = &"happy_bounce", cue = &"finale"},
		],
	},
	&"bone": {
		hold = Vector3(0.0, -0.01, 0.02), end_sfx = [&"woof"],
		steps = [
			{cue = &"drop", sec = 0.8},
			_SNIFF,
			{cue = &"lift", sec = 0.45},
			_CHEW_BONE, _CHEW_BONE,
			_POP_OUT,
			{clip = &"happy_wiggle", stand_in = &"happy_bounce", cue = &"finale"},
		],
	},
	&"yarn": {
		end_sfx = [&"giggle"],
		steps = [
			{cue = &"roll_in", sec = 0.9},
			{clip = &"bat_paw_L", stand_in = &"paw_highfive_L", sec = 0.5, hold = 0.55, side = -1.0, beats = CONTACT, beat = &"bat"},
			{clip = &"bat_paw_R", stand_in = &"paw_highfive_R", sec = 0.5, hold = 0.55, side = 1.0, beats = CONTACT, beat = &"bat"},
			{clip = &"bat_paw_L", stand_in = &"paw_highfive_L", sec = 0.5, hold = 0.55, side = -1.0, beats = CONTACT, beat = &"bat"},
			{cue = &"roll_off", sec = 0.9},
			{clip = &"giggle", cue = &"finale"},
		],
	},
	&"ball": {
		end_sfx = [&"giggle"],
		steps = [
			{cue = &"bounce_in", sec = 1.2},
			{clip = &"bat_paw_L", stand_in = &"paw_highfive_L", sec = 0.5, hold = 0.3, side = -1.0, beats = CONTACT, beat = &"hop"},
			{clip = &"bat_paw_R", stand_in = &"paw_highfive_R", sec = 0.5, hold = 0.3, side = 1.0, beats = CONTACT, beat = &"hop"},
			{clip = &"happy_wiggle", stand_in = &"happy_bounce"},
			{cue = &"roll_off", sec = 0.9},
			{cue = &"finale", sec = 0.5},
		],
	},
	&"bell": {
		end_sfx = [&"twinkle"],
		steps = [
			{cue = &"lower_in", sec = 0.7},
			{clip = &"bat_paw_R", stand_in = &"paw_highfive_R", sec = 0.5, hold = 0.45, side = 1.0, beats = CONTACT, beat = &"swing"},
			{clip = &"bat_paw_L", stand_in = &"paw_highfive_L", sec = 0.5, hold = 0.45, side = -1.0, beats = CONTACT, beat = &"swing"},
			{clip = &"bat_paw_R", stand_in = &"paw_highfive_R", sec = 0.5, hold = 0.45, side = 1.0, beats = CONTACT, beat = &"swing"},
			{cue = &"rise_away", sec = 0.6},
			{clip = &"happy_bounce", cue = &"finale"},
		],
	},
}


## How long a step's beats spread over, given the length of the clip it played.
static func span(step: Dictionary, clip_sec: float) -> float:
	return maxf(clip_sec, step.get("sec", 0.0))


## A clip shorter than its step (a stand-in) plays again on every beat.
static func replays(step: Dictionary, clip_sec: float) -> bool:
	return clip_sec > 0.0 and clip_sec < step.get("sec", 0.0)


static func duration(step: Dictionary, clip_sec: float) -> float:
	return span(step, clip_sec) + step.get("hold", 0.0)


## Liquid left after beat `beat` of `beats`, draining evenly down to `last`.
static func level_after(beat: int, beats: int, last: float) -> float:
	return lerpf(1.0, last, float(beat + 1) / beats)


static func stage_after(stage: int) -> int:
	return mini(stage + 1, LAST_STAGE)
