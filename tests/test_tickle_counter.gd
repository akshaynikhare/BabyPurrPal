extends TestCase

const L := TickleCounter.Level


func test_five_quick_tickles_build_to_a_tumble() -> void:
	var counter := TickleCounter.new()
	var levels := []
	for i in 6:
		levels.append(counter.tap(1000 + i * 400))
	check_eq(levels, [L.GIGGLE, L.GIGGLE, L.LAUGH, L.LAUGH, L.TUMBLE, L.GIGGLE], "levels")


func test_a_pause_starts_over() -> void:
	var counter := TickleCounter.new()
	counter.tap(0)
	counter.tap(1000)
	check_eq(counter.tap(2500), L.LAUGH, "1500 ms apart still counts")
	check_eq(counter.tap(4001), L.GIGGLE, "1501 ms apart starts over")
	check_eq(counter.count, 1, "count after the pause")


func test_reset() -> void:
	var counter := TickleCounter.new()
	counter.tap(0)
	counter.tap(100)
	counter.reset()
	check_eq(counter.tap(200), L.GIGGLE, "after reset")
