extends TestCase


func test_never_repeats_back_to_back() -> void:
	for count in [2, 3, 5]:
		var picker := NoRepeatPicker.new(count, 7)
		var last := -1
		for i in 300:
			var value := picker.pick()
			check(value != last, "count %d repeated %d at pick %d" % [count, value, i])
			check(value >= 0 and value < count, "out of range %d" % value)
			last = value


func test_each_round_uses_every_option() -> void:
	var picker := NoRepeatPicker.new(4, 11)
	for round_i in 50:
		var seen := {}
		for i in 4:
			seen[picker.pick()] = true
		check_eq(seen.size(), 4, "round %d" % round_i)


func test_single_option_always_zero() -> void:
	var picker := NoRepeatPicker.new(1, 3)
	for i in 5:
		check_eq(picker.pick(), 0, "single option")


func test_two_options_alternate() -> void:
	var picker := NoRepeatPicker.new(2, 5)
	var first := picker.pick()
	for i in 20:
		check_eq(picker.pick(), 1 - first if i % 2 == 0 else first, "alternation at %d" % i)
