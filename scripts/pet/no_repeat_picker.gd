class_name NoRepeatPicker
extends RefCounted
## Shuffle bag: every option comes up once per round, and never twice in a row,
## even across rounds.

var _count := 0
var _bag := PackedInt32Array()
var _last := -1
var _rng := RandomNumberGenerator.new()


func _init(count: int, seed_value: int = -1) -> void:
	_count = maxi(count, 1)
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


func pick() -> int:
	if _bag.is_empty():
		_refill()
	var value := _bag[_bag.size() - 1]
	_bag.remove_at(_bag.size() - 1)
	_last = value
	return value


func _refill() -> void:
	_bag.resize(_count)
	for i in _count:
		_bag[i] = i
	for i in range(_count - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := _bag[i]
		_bag[i] = _bag[j]
		_bag[j] = tmp
	# The bag is popped from the end; keep last round's pick off the top.
	if _count > 1 and _bag[_count - 1] == _last:
		var tmp := _bag[0]
		_bag[0] = _bag[_count - 1]
		_bag[_count - 1] = tmp
