class_name PetReactions
extends RefCounted
## Data for the zone, toy and greeting reactions (REWRITE_SPEC tables).
## Keys per reaction: sfx (played 0.15 s apart), haptic, mood + ms, fx + count,
## mimic (babble if talk-back is idle), fx_needs_mimic, chomp (jaw munches), purr.

const PET_IDS: Array[StringName] = [&"cat", &"dog", &"bunny"]
const PET_NAMES: Array[String] = ["Kitty Cat 🐱", "Puppy Dog 🐶", "Bunny Rabbit 🐰"]
const ZONES: Array[StringName] = [&"belly", &"ears", &"cheeks", &"mouth", &"paw_L", &"paw_R"]

const HAPPY := &"happy"
const TICKLED := &"tickled"
const PURR := &"purr"

## Animation variants per zone; a variant plays its clips in order.
const ZONE_ANIMS := {
	&"belly": [[&"giggle"], [&"happy_bounce"], [&"giggle", &"ear_perk"]],
	&"ears": [[&"ear_perk"], [&"listen_nod"], [&"ear_perk", &"happy_bounce"]],
	&"cheeks": [[&"giggle"], [&"listen_nod"], [&"look_around"]],
	&"mouth": [[&"happy_bounce"], [&"listen_nod"]],
	&"paw_L": [[&"paw_highfive_L"], [&"paw_highfive_L", &"happy_bounce"]],
	&"paw_R": [[&"paw_highfive_R"], [&"paw_highfive_R", &"happy_bounce"]],
}

const MOOD_ANIMS := {
	&"happy": [[&"happy_bounce"], [&"happy_bounce", &"listen_nod"]],
	&"tickled": [[&"giggle"], [&"giggle", &"happy_bounce"]],
	&"purr": [[&"ear_perk"], [&"listen_nod"]],
}

## Belly tickles in a row build up (TickleCounter); these replace the belly
## animation, bubble count and tickled time, add a giggle, a squash and a wobble.
const TICKLES := {
	TickleCounter.Level.LAUGH: {anims = [&"giggle", &"happy_wiggle"], count = 12, ms = 1200, squash = 0.14, wobble = 0.09},
	TickleCounter.Level.TUMBLE: {anims = [&"laugh_tumble"], count = 16, ms = 1800, squash = 0.18, wobble = 0.16},
}

const _PAW := {sfx = [&"paw_tap"], haptic = &"paw", fx = &"paw", count = 5}

const ZONE_REACTIONS := {
	&"cat": {
		&"belly": {sfx = [&"giggle"], haptic = &"tickle", mood = &"tickled", ms = 600, fx = &"bubble", count = 8},
		&"ears": {sfx = [&"twinkle"], haptic = &"purr", mood = &"purr", ms = 1600, purr = true, fx = &"heart", count = 7},
		&"cheeks": {sfx = [&"twinkle"], haptic = &"twinkle", fx = &"sparkle", count = 6},
		&"mouth": {haptic = &"bounce", mimic = true, fx = &"star", count = 6, fx_needs_mimic = true},
		&"paw": _PAW,
	},
	&"dog": {
		&"belly": {sfx = [&"giggle", &"pant"], haptic = &"tickle", mood = &"tickled", ms = 600, fx = &"bubble", count = 8},
		&"ears": {sfx = [&"pant"], haptic = &"bounce", mood = &"happy", ms = 1400, fx = &"heart", count = 7},
		&"cheeks": {sfx = [&"woof"], haptic = &"bounce", mimic = true, fx = &"star", count = 6},
		&"mouth": {sfx = [&"woof"], haptic = &"bounce", mimic = true, fx = &"star", count = 6},
		&"paw": _PAW,
	},
	&"bunny": {
		&"belly": {sfx = [&"giggle"], haptic = &"tickle", mood = &"tickled", ms = 600, fx = &"bubble", count = 8},
		&"ears": {sfx = [&"squeak"], haptic = &"bounce", mood = &"happy", ms = 1200, fx = &"heart", count = 7},
		&"cheeks": {sfx = [&"twinkle"], haptic = &"twinkle", fx = &"sparkle", count = 6},
		&"mouth": {sfx = [&"crunch"], haptic = &"feed", mimic = true, fx = &"star", count = 6, chomp = true},
		&"paw": _PAW,
	},
}

const TOYS := {
	&"milk": {sfx = [], mood = &"purr", ms = 1500, purr = true, fx = &"heart", count = 8, chomp = true},
	&"fish": {sfx = [&"paw_tap"], mood = &"tickled", ms = 500, fx = &"star", count = 8, chomp = true},
	&"yarn": {sfx = [&"giggle"], mood = &"tickled", ms = 500, fx = &"bubble", count = 10},
	&"bone": {sfx = [&"paw_tap", &"woof"], mood = &"happy", ms = 1000, fx = &"star", count = 8, chomp = true},
	&"ball": {sfx = [&"giggle"], mood = &"tickled", ms = 500, fx = &"bubble", count = 9},
	&"water": {sfx = [&"pant"], mood = &"happy", ms = 1200, fx = &"heart", count = 7, chomp = true},
	&"carrot": {sfx = [&"crunch"], mood = &"happy", ms = 1000, fx = &"star", count = 8, chomp = true},
	&"clover": {sfx = [&"squeak"], mood = &"happy", ms = 1000, fx = &"heart", count = 8, chomp = true},
	&"bell": {sfx = [&"twinkle"], mood = &"tickled", ms = 500, fx = &"bubble", count = 9},
}

const GREETINGS := {
	&"cat": {sfx = [], haptic = &"purr", mood = &"purr", ms = 1200, purr = true},
	&"dog": {sfx = [&"woof"], haptic = &"bounce", mood = &"happy", ms = 1200},
	&"bunny": {sfx = [&"squeak"], haptic = &"bounce", mood = &"happy", ms = 1200},
}


static func zone_reaction(pet_id: StringName, zone: StringName) -> Dictionary:
	var key := &"paw" if zone == &"paw_L" or zone == &"paw_R" else zone
	return ZONE_REACTIONS[pet_id][key]
