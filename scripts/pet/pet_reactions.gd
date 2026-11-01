class_name PetReactions
extends RefCounted
## Data for the zone, toy and greeting reactions (REWRITE_SPEC tables).
## Keys per reaction: sfx (played 0.15 s apart), haptic, mood + ms, voice,
## mimic (babble if talk-back is idle), chomp (jaw munches), purr, wobble (body
## wobble), twitch (nose twitches); toys also use fx + count (particle burst).
## voice is a PetVoice line for PetVoice.say(): a clip id (&"hooray"), a random
## clip of a numbered set (&"laugh*" = laugh_1..4, no immediate repeats), one of
## several (&"ooh|giggle*"), or lines back to back (&"laugh*+hooray").
## A zone has a voice or mimics, never both: the babble would cut the voice off.
## sfx are each pet's own calls: the cat meows, chirps and trills, the dog woofs,
## yips and pants, the bunny squeaks and snuffles; a belly tickle boings.

const PET_IDS: Array[StringName] = [&"cat", &"dog", &"bunny"]
const PET_NAMES: Array[String] = ["Kitty Cat 🐱", "Puppy Dog 🐶", "Bunny Rabbit 🐰"]
const ZONES: Array[StringName] = [&"belly", &"ears", &"cheeks", &"mouth", &"paw_L", &"paw_R"]

const HAPPY := &"happy"
const TICKLED := &"tickled"
const PURR := &"purr"

## Animation variants per zone; a variant plays its clips in order.
const ZONE_ANIMS := {
	&"belly": [[&"laugh"], [&"laugh", &"happy_wiggle"], [&"giggle", &"happy_wiggle"]],
	&"ears": [[&"ear_perk", &"head_shake"], [&"ear_perk", &"listen_nod"], [&"ear_perk", &"head_shake", &"happy_bounce"]],
	&"cheeks": [[&"giggle"], [&"giggle", &"listen_nod"], [&"giggle", &"look_around"]],
	&"mouth": [[&"happy_bounce"], [&"listen_nod"]],
	&"paw_L": [[&"paw_highfive_L"], [&"paw_highfive_L", &"happy_bounce"]],
	&"paw_R": [[&"paw_highfive_R"], [&"paw_highfive_R", &"happy_bounce"]],
}

## Stand-ins for clips the GLBs don't have yet (the player has to resolve these
## like PetClips.FALLBACKS, or a variant that starts with one plays nothing).
const ANIM_FALLBACKS := {
	&"laugh": &"giggle",
	&"head_shake": &"look_around",
}

const MOOD_ANIMS := {
	&"happy": [[&"happy_bounce"], [&"happy_bounce", &"listen_nod"]],
	&"tickled": [[&"giggle"], [&"giggle", &"happy_bounce"]],
	&"purr": [[&"ear_perk"], [&"listen_nod"]],
}

## Belly tickles in a row build up (TickleCounter): a level's voice replaces the
## belly's; LAUGH and TUMBLE also replace the animation and tickled time and add
## a squash and a wobble.
const TICKLES := {
	TickleCounter.Level.GIGGLE: {voice = &"giggle*"},
	TickleCounter.Level.LAUGH: {voice = &"laugh*", anims = [&"laugh", &"happy_wiggle"], ms = 1200, squash = 0.14, wobble = 0.09},
	TickleCounter.Level.TUMBLE: {voice = &"laugh*+hooray", anims = [&"laugh_tumble"], ms = 1800, squash = 0.18, wobble = 0.16},
}

const _PAW := {sfx = [&"paw_tap"], haptic = &"paw", voice = &"squeal*"}

const ZONE_REACTIONS := {
	&"cat": {
		&"belly": {sfx = [&"boing"], voice = &"laugh*", haptic = &"tickle", mood = &"tickled", ms = 600, wobble = 0.06},
		&"ears": {sfx = [&"trill"], voice = &"ooh|giggle*", haptic = &"purr", mood = &"purr", ms = 1600, purr = true},
		&"cheeks": {sfx = [&"chirp"], voice = &"giggle*", haptic = &"twinkle", twitch = 2},
		&"mouth": {sfx = [&"meow"], haptic = &"bounce", mimic = true},
		&"paw": _PAW,
	},
	&"dog": {
		&"belly": {sfx = [&"boing", &"pant"], voice = &"laugh*", haptic = &"tickle", mood = &"tickled", ms = 600, wobble = 0.06},
		&"ears": {sfx = [&"pant"], voice = &"ooh|giggle*", haptic = &"bounce", mood = &"happy", ms = 1400},
		&"cheeks": {sfx = [&"yip"], voice = &"giggle*", haptic = &"bounce", twitch = 2},
		&"mouth": {sfx = [&"woof"], haptic = &"bounce", mimic = true},
		&"paw": _PAW,
	},
	&"bunny": {
		&"belly": {sfx = [&"boing"], voice = &"laugh*", haptic = &"tickle", mood = &"tickled", ms = 600, wobble = 0.06},
		&"ears": {sfx = [&"squeak"], voice = &"ooh|giggle*", haptic = &"bounce", mood = &"happy", ms = 1200},
		&"cheeks": {sfx = [&"snuffle"], voice = &"giggle*", haptic = &"twinkle", twitch = 3},
		&"mouth": {sfx = [&"crunch"], haptic = &"feed", mimic = true, chomp = true},
		&"paw": _PAW,
	},
}

## The toy finale's mood; its sound is the toy's end_sfx / end_voice (ToyScript).
const TOYS := {
	&"milk": {mood = &"purr", ms = 1500, purr = true, fx = &"heart", count = 8, chomp = true},
	&"fish": {mood = &"tickled", ms = 500, fx = &"star", count = 8, chomp = true},
	&"yarn": {mood = &"tickled", ms = 500, fx = &"bubble", count = 10},
	&"bone": {mood = &"happy", ms = 1000, fx = &"star", count = 8, chomp = true},
	&"ball": {mood = &"tickled", ms = 500, fx = &"bubble", count = 9},
	&"water": {mood = &"happy", ms = 1200, fx = &"heart", count = 7, chomp = true},
	&"carrot": {mood = &"happy", ms = 1000, fx = &"star", count = 8, chomp = true},
	&"clover": {mood = &"happy", ms = 1000, fx = &"heart", count = 8, chomp = true},
	&"bell": {mood = &"tickled", ms = 500, fx = &"bubble", count = 9},
}

## The walk-in greeting; its line follows the time of day (greeting_line).
const GREETINGS := {
	&"cat": {sfx = [&"meow"], voice = &"hello*", haptic = &"purr", mood = &"purr", ms = 1200, purr = true},
	&"dog": {sfx = [&"woof"], voice = &"hello*", haptic = &"bounce", mood = &"happy", ms = 1200},
	&"bunny": {sfx = [&"squeak"], voice = &"hello*", haptic = &"bounce", mood = &"happy", ms = 1200},
}
const PHASE_GREETINGS := {TimeOfDay.SUNRISE: &"morning", TimeOfDay.NIGHT: &"night"}

## The wave after a quiet spell: no buzz (the phone may be lying on a table).
const COME_PLAY := {
	&"cat": {sfx = [&"meow"], voice = &"come_play*", mood = &"happy", ms = 1200},
	&"dog": {sfx = [&"whine"], voice = &"come_play*", mood = &"happy", ms = 1200},
	&"bunny": {sfx = [&"snuffle"], voice = &"come_play*", mood = &"happy", ms = 1200},
}

## Idle lines: a yawn with the yawn clip at night, and now and then a hum along
## with the lullaby.
const YAWN := &"yawn"
const HUM := &"hum"
const HUM_CHANCE := 0.25


static func zone_reaction(pet_id: StringName, zone: StringName) -> Dictionary:
	var key := &"paw" if zone == &"paw_L" or zone == &"paw_R" else zone
	return ZONE_REACTIONS[pet_id][key]


## Good morning at sunrise, nighty night at night, else a hello.
static func greeting_line(pet_id: StringName, phase: StringName) -> StringName:
	return PHASE_GREETINGS.get(phase, GREETINGS[pet_id].voice)


## Said as the toy appears.
static func toy_line(toy_id: StringName) -> StringName:
	return StringName("toy_" + toy_id)
