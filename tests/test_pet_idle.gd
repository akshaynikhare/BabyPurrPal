extends TestCase

const E := PetIdle.Event
## Exact in binary, so the clock adds up without drift.
const STEP := 0.125


## Steps the schedule and returns the times (s) each event fired.
func _run(idle: PetIdle, seconds: float, event: PetIdle.Event, free := true) -> Array:
	var times := []
	for i in int(seconds / STEP):
		if idle.update(STEP, free) == event:
			times.append((i + 1) * STEP)
	return times


func test_breaks_come_every_5_to_10_s() -> void:
	var idle := PetIdle.new(3)
	var times := _run(idle, 19.875, E.BREAK)
	check(times.size() >= 2, "at least two breaks before the call, got %s" % [times])
	var last := 0.0
	for t in times:
		check(t - last >= 5.0 - STEP and t - last <= 10.0 + STEP, "gap %.3f" % (t - last))
		last = t


func test_come_play_after_20_s_then_every_30_s() -> void:
	var idle := PetIdle.new(5)
	check_eq(_run(idle, 80.0, E.COME_PLAY), [20.0, 50.0, 80.0], "calls")


func test_a_touch_restarts_the_quiet_clock() -> void:
	var idle := PetIdle.new(5)
	_run(idle, 15.0, E.COME_PLAY)
	idle.touched()
	check_eq(_run(idle, 20.0, E.COME_PLAY), [20.0], "20 s after the touch")


func test_due_events_wait_until_the_pet_is_free() -> void:
	var idle := PetIdle.new(5)
	check_eq(_run(idle, 25.0, E.COME_PLAY, false), [], "nothing while busy")
	check_eq(idle.update(STEP, true), E.COME_PLAY, "fires once free")


func test_nose_twitches_every_3_to_6_s() -> void:
	var idle := PetIdle.new(9)
	var last := 0.0
	var fired := 0
	for i in int(30.0 / STEP):
		var t := (i + 1) * STEP
		var twitches := idle.nose(STEP)
		if twitches > 0:
			fired += 1
			check(twitches == 2 or twitches == 3, "twitches %d" % twitches)
			check(t - last >= 3.0 - STEP and t - last <= 6.0 + STEP, "gap %.3f" % (t - last))
			last = t
	check(fired >= 5, "fired %d times in 30 s" % fired)


func test_surprises_are_rare_and_wait_until_free() -> void:
	var idle := PetIdle.new(7)
	var times := []
	for i in int(300.0 / STEP):
		idle.update(STEP, true)
		if idle.surprise(STEP, true):
			times.append((i + 1) * STEP)
	check(times.size() >= 3 and times.size() <= 7, "a sneeze or hiccup every 45–90 s, got %s" % [times])
	var last := 0.0
	for t in times:
		check(t - last >= PetIdle.SURPRISE_MIN_SEC - STEP and t - last <= PetIdle.SURPRISE_MAX_SEC + STEP, "gap %.3f" % (t - last))
		last = t
	var busy := PetIdle.new(7)
	for i in int(120.0 / STEP):
		check(not busy.surprise(STEP, false), "never while busy")


func test_surprises_leave_the_break_timing_alone() -> void:
	var plain := PetIdle.new(3)
	var surprised := PetIdle.new(3)
	for i in int(60.0 / STEP):
		check_eq(surprised.update(STEP, true), plain.update(STEP, true), "same events at %.3f" % ((i + 1) * STEP))
		surprised.surprise(STEP, true)
