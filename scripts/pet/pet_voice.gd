class_name PetVoice
extends Node
## Each pet's own voice: laughs, giggles and squeals rendered offline into
## assets/audio/voice/<pet id>/ (see MANIFEST.md), played through TalkBack.play_clip
## at their own pitch, with mouth sync and the mic gate.
## A line passed to say() is one of:
##   laugh_1         that clip
##   laugh*          a random laugh_N, never the same one twice in a row
##   ooh|giggle*     one of these clips, picked the same way
##   laugh*+hooray   several, back to back (the next starts when the last ends)
## The pet never talks over the child (LISTEN) or over their echo; a touch may
## cut its own line short.

const DIR := "res://assets/audio/voice/"
const ENVELOPES := "envelopes.json"
const RANDOM := "*"
const EITHER := "|"
const THEN := "+"

var _talkback: TalkBack
## Pet id → its clips: {streams, envelopes, groups, pickers, lines}, loaded up front
## so switching pets never loads files.
var _sets := {}
## The current pet's set.
var _streams := {}
var _envelopes := {}
## &"laugh*" or &"ooh|giggle*" → its clip ids, and a picker for each.
var _groups := {}
var _pickers := {}
## Parsed say() lines, so a repeated line costs no string work.
var _lines := {}
var _queue: Array[StringName] = []
## The clip TalkBack is playing (or just finished) is one of ours.
var _speaking := false


func _init(talkback: TalkBack, pet_ids: Array[StringName] = [&"cat"]) -> void:
	_talkback = talkback
	for pet_id in pet_ids:
		_sets[pet_id] = _load_set(pet_id)
	use_pet(pet_ids[0])
	EventBus.talkback_state_changed.connect(_on_talk_state)


## Speaks with this pet's clips from now on; a chained line stops chaining.
func use_pet(pet_id: StringName) -> void:
	var clips: Dictionary = _sets[pet_id]
	_streams = clips.streams
	_envelopes = clips.envelopes
	_groups = clips.groups
	_pickers = clips.pickers
	_lines = clips.lines
	_queue.clear()


func _load_set(pet_id: StringName) -> Dictionary:
	var clips := {streams = {}, envelopes = {}, groups = {}, pickers = {}, lines = {}}
	var dir := DIR + pet_id + "/"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + ENVELOPES))
	if not data is Dictionary:
		push_warning("PetVoice: no envelopes at " + dir + ENVELOPES)
		return clips
	for key: String in data:
		var path := dir + key + ".wav"
		if not ResourceLoader.exists(path):
			continue
		var id := StringName(key)
		clips.streams[id] = load(path)
		clips.envelopes[id] = PackedFloat32Array(data[key])
		var cut := key.rfind("_")
		if cut > 0 and key.substr(cut + 1).is_valid_int():
			var group := StringName(key.left(cut) + RANDOM)
			if not clips.groups.has(group):
				var ids: Array[StringName] = []
				clips.groups[group] = ids
			(clips.groups[group] as Array[StringName]).append(id)
	for group: StringName in clips.groups:
		clips.pickers[group] = NoRepeatPicker.new((clips.groups[group] as Array).size())
	return clips


## Every part of the line names a clip or a non-empty group.
func has(line: StringName) -> bool:
	for part in _parts(line):
		if not _streams.has(part) and not _groups.has(part):
			return false
	return true


func say(line: StringName) -> void:
	if not _may_speak():
		return
	var parts := _parts(line)
	_queue.assign(parts.slice(1))
	_play(parts[0])


## One of prefix_1, prefix_2, ... without an immediate repeat.
func say_random(prefix: StringName) -> void:
	say(StringName(prefix + RANDOM))


func _may_speak() -> bool:
	if _talkback.is_inside_tree() and not _talkback.can_process():
		return false
	match _talkback.state:
		TalkBack.LISTEN:
			return false
		TalkBack.TALK, TalkBack.CELEBRATE:
			return _speaking
	return true


func _parts(line: StringName) -> Array[StringName]:
	if not _lines.has(line):
		var parts: Array[StringName] = []
		for part in String(line).split(THEN, false):
			parts.append(StringName(part))
			if part.contains(EITHER):
				_add_either(StringName(part))
		if parts.is_empty():
			parts.append(line)
		_lines[line] = parts
	return _lines[line]


## A group for "a|b*|...", only if every choice exists.
func _add_either(part: StringName) -> void:
	var ids: Array[StringName] = []
	for choice in String(part).split(EITHER, false):
		var key := StringName(choice)
		if _groups.has(key):
			ids.append_array(_groups[key])
		elif _streams.has(key):
			ids.append(key)
		else:
			return
	_groups[part] = ids
	_pickers[part] = NoRepeatPicker.new(ids.size())


func _play(part: StringName) -> void:
	var id := part
	if _groups.has(part):
		id = (_groups[part] as Array[StringName])[(_pickers[part] as NoRepeatPicker).pick()]
	if not _streams.has(id):
		push_warning("PetVoice: no line " + id)
		_queue.clear()
		return
	_speaking = true
	_talkback.play_clip(_streams[id], _envelopes[id], false)


func _on_talk_state(state: StringName) -> void:
	if state == TalkBack.TALK:
		return
	if state == TalkBack.CELEBRATE:
		# Deferred: TalkBack is still announcing CELEBRATE to the other listeners.
		if _speaking and not _queue.is_empty():
			_play_next.call_deferred()
		return
	_speaking = false
	_queue.clear()


func _play_next() -> void:
	if _queue.is_empty() or _talkback.state != TalkBack.CELEBRATE or not _may_speak():
		return
	_play(_queue.pop_front())
