class_name ToyScript
extends RefCounted
## Toy sessions as data: per toy, the steps the pet and its prop go through.
## A step plays `clip` (or `stand_in` while the GLB lacks it), fires `cue` as it
## starts and `beat` at each fraction in `beats` of its span, then waits `hold`.
## The span is the longest of the clip, `sec` and what the cue needs (a run); a
## clip shorter than `sec` (a stand-in) plays again on every beat. `rest` is the
## pose held between clips from then on (sit_idle once seated, &"" once up);
## `side` is where a paw sends the toy: -1 toward the pet's right, +1 its left.
## Per toy: grip (prop origin from the paws' hold bone; the bone sits level
## with the face, so props come forward to stay in sight), hold (from the mouth,
## while the GLB has no hold bone), tilt (toward the mouth; floating in front
## of it, or tipping the cup while drinking), drain_to (liquid
## left), end_sfx and end_voice (said instead of the sfx when the line exists),
## chase (the pet runs after the toy; the prop keeps world axes to roll).
## Prop sounds: appear_sfx (as it pops in, 0.15 s apart; default pop_in), lift_sfx
## (as the paws take it), roll_sfx (kicked or rolling along the floor), eat_sfx
## (bites, instead of the pet's own PetSounds.EAT).

const POP_SEC := 0.35
## Prop stages run 0 (whole) to 3 (eaten).
const LAST_STAGE := 3
const LAPS: Array[float] = [0.125, 0.375, 0.625, 0.875]
## Chew peak of each sit_hold_eat loop.
const CHEW: Array[float] = [0.5]
## The swiping paw meets the toy a little before the clip's middle.
const CONTACT: Array[float] = [0.45]
## Landing of a pounce.
const LANDING: Array[float] = [0.6]
## Clips the pet GLBs have today; anything newer needs one of them as stand-in,
## or a `sec` so the step still takes its time without it.
const BASE_CLIPS: Array[StringName] = [
	&"happy_bounce", &"happy_wiggle", &"giggle", &"listen_nod", &"ear_perk", &"sniff",
	&"drink", &"lap", &"bite", &"chew", &"bat_paw_L", &"bat_paw_R", &"walk_in",
]
const SIT := &"sit_idle"
const LIE := &"lie_play"
## PetVoice line: one of the yum clips, never the same twice in a row.
const YUM := &"yum*"

const _EXCITED := {clip = &"excited", stand_in = &"happy_bounce", sec = 0.6}
const _SIT_DOWN := {clip = &"sit_down", sec = 0.35, rest = SIT}
const _SIT_DOWN_LIFT := {clip = &"sit_down", sec = 0.5, rest = SIT, cue = &"lift"}
const _STAND_UP := {clip = &"stand_up", sec = 0.35, rest = &""}
const _EAT := {clip = &"sit_hold_eat", stand_in = &"chew", sec = 0.8, beats = CHEW, beat = &"bite"}
## The last loop eats the last bite and the rest pops out.
const _EAT_LAST := {clip = &"sit_hold_eat", stand_in = &"chew", sec = 0.8, beats = [0.5, 0.85], beat = &"bite_out"}
const _GNAW := {clip = &"sit_hold_eat", stand_in = &"chew", sec = 0.8, beats = CHEW, beat = &"gnaw"}
const _GNAW_LAST := {clip = &"sit_hold_eat", stand_in = &"chew", sec = 0.8, beats = [0.5, 0.85], beat = &"gnaw_out"}
const _SIT_BAT_R := {clip = &"sit_bat_R", stand_in = &"bat_paw_R", sec = 0.5, hold = 0.45, side = 1.0, beats = CONTACT, beat = &"swing"}
const _SIT_BAT_L := {clip = &"sit_bat_L", stand_in = &"bat_paw_L", sec = 0.5, hold = 0.45, side = -1.0, beats = CONTACT, beat = &"swing"}
const _POP_IN := {cue = &"pop_floor", sec = POP_SEC}
const _POP_OUT := {cue = &"pop_out", sec = POP_SEC}
const _CHASE := {cue = &"chase", sec = 0.3}
const _POUNCE := {clip = &"pounce", stand_in = &"happy_bounce", sec = 0.7, cue = &"leap", beats = LANDING, beat = &"pounce"}
const _KICK := {clip = &"bat_paw_R", stand_in = &"happy_bounce", sec = 0.5, beats = CONTACT, beat = &"kick"}
const _ROLL_OFF := {cue = &"roll_off", sec = 0.5}
const _HOME := {cue = &"home", sec = 0.3}

const TOYS := {
	&"milk": {
		grip = Vector3(0.0, -0.05, 0.07), hold = Vector3(0.0, -0.15, 0.13), tilt = deg_to_rad(-35.0),
		drain_to = 0.02, end_sfx = [&"yum"], end_voice = YUM,
		appear_sfx = [&"pop_in", &"pour_milk"], lift_sfx = &"clink",
		steps = [
			_POP_IN,
			_EXCITED,
			_SIT_DOWN_LIFT,
			{clip = &"sit_hold_drink", stand_in = &"drink", sec = 2.0, cue = &"drink", beats = [0.25, 0.46, 0.67, 0.8], beat = &"gulp"},
			_STAND_UP,
			{clip = &"ear_perk", cue = &"finale"},
		],
	},
	&"water": {
		drain_to = 0.3, end_sfx = [&"pant"], appear_sfx = [&"bowl", &"pour_water"],
		steps = [
			_POP_IN,
			_EXCITED,
			_SIT_DOWN,
			{clip = &"sit_lap", stand_in = &"lap", sec = 1.6, beats = LAPS, beat = &"lap"},
			_STAND_UP,
			_POP_OUT,
			{clip = &"happy_bounce", cue = &"finale"},
		],
	},
	&"fish": {
		grip = Vector3(0.0, 0.02, 0.08), hold = Vector3(0.0, -0.04, 0.09), end_sfx = [&"yum"], end_voice = YUM,
		steps = [
			{cue = &"pop_hover", sec = POP_SEC},
			_EXCITED,
			_SIT_DOWN_LIFT,
			_EAT, _EAT, _EAT_LAST,
			_STAND_UP,
			{clip = &"giggle", cue = &"finale"},
		],
	},
	&"carrot": {
		grip = Vector3(0.0, -0.02, 0.07), hold = Vector3(0.0, -0.07, 0.105), tilt = deg_to_rad(-46.0),
		end_sfx = [&"yum"], end_voice = YUM,
		steps = [
			{cue = &"pop_hover", sec = POP_SEC},
			_EXCITED,
			_SIT_DOWN_LIFT,
			_EAT, _EAT, _EAT_LAST,
			_STAND_UP,
			{clip = &"happy_bounce", cue = &"finale"},
		],
	},
	&"clover": {
		end_sfx = [&"yum"], end_voice = YUM, eat_sfx = &"munch",
		steps = [
			_POP_IN,
			_EXCITED,
			_SIT_DOWN,
			{clip = &"sit_lap", stand_in = &"lap", sec = 1.6, beats = LAPS, beat = &"nibble"},
			_STAND_UP,
			_POP_OUT,
			{clip = &"happy_bounce", cue = &"finale"},
		],
	},
	&"bone": {
		grip = Vector3(0.0, 0.0, 0.03), hold = Vector3(0.0, -0.01, 0.02), end_sfx = [&"sigh"], lift_sfx = &"squeaky",
		steps = [
			{cue = &"drop", sec = 0.8},
			{clip = &"sniff", stand_in = &"listen_nod", sec = 0.6, cue = &"sniff"},
			_EXCITED,
			_SIT_DOWN_LIFT,
			_GNAW, _GNAW, _GNAW_LAST,
			_STAND_UP,
			{clip = &"happy_wiggle", stand_in = &"happy_bounce", cue = &"finale"},
		],
	},
	&"yarn": {
		chase = true, end_sfx = [&"giggle"], roll_sfx = &"roll",
		steps = [
			{cue = &"roll_in", sec = 0.4},
			_EXCITED,
			_CHASE, _POUNCE, _KICK,
			_CHASE, _POUNCE,
			{clip = &"lie_down", sec = 0.35, rest = LIE, cue = &"to_paws"},
			{clip = &"lie_play", stand_in = &"giggle", sec = 1.4, beats = [0.25, 0.75], beat = &"juggle"},
			{clip = &"lie_play", stand_in = &"giggle", sec = 1.4, beats = [0.25, 0.75], beat = &"juggle"},
			{clip = &"get_up", sec = 0.35, rest = &"", cue = &"drop_ball"},
			_ROLL_OFF,
			_HOME,
			{clip = &"giggle", cue = &"finale"},
		],
	},
	&"ball": {
		chase = true, end_sfx = [&"giggle"], roll_sfx = &"bounce",
		steps = [
			{cue = &"bounce_in", sec = 0.5},
			_EXCITED,
			_CHASE, _POUNCE, _KICK,
			_CHASE, _POUNCE,
			{clip = &"happy_wiggle", stand_in = &"happy_bounce"},
			{clip = &"jump", stand_in = &"happy_bounce"},
			_ROLL_OFF,
			_HOME,
			{cue = &"finale", sec = 0.5},
		],
	},
	&"bell": {
		end_sfx = [&"twinkle"],
		steps = [
			{cue = &"lower_in", sec = 0.7},
			_EXCITED,
			{clip = &"sit_down", sec = 0.35, rest = SIT, cue = &"sit_bell"},
			_SIT_BAT_R, _SIT_BAT_L, _SIT_BAT_R,
			{cue = &"rise_away", sec = 0.6},
			_STAND_UP,
			{clip = &"happy_bounce", cue = &"finale"},
		],
	},
}


## How long a step's beats spread over, given the length of the clip it played
## and what its cue needs.
static func span(step: Dictionary, clip_sec: float, cue_sec := 0.0) -> float:
	return maxf(maxf(clip_sec, cue_sec), step.get("sec", 0.0))


## A clip shorter than its step (a stand-in) plays again on every beat.
static func replays(step: Dictionary, clip_sec: float) -> bool:
	return clip_sec > 0.0 and clip_sec < step.get("sec", 0.0)


static func duration(step: Dictionary, clip_sec: float, cue_sec := 0.0) -> float:
	return span(step, clip_sec, cue_sec) + step.get("hold", 0.0)


## Liquid left after beat `beat` of `beats`, draining evenly down to `last`.
static func level_after(beat: int, beats: int, last: float) -> float:
	return lerpf(1.0, last, float(beat + 1) / beats)


static func stage_after(stage: int) -> int:
	return mini(stage + 1, LAST_STAGE)
