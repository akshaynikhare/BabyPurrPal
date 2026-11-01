extends TestCase

const DT := 1.0 / 60.0


func _hold(g: HoldGate, seconds: float) -> bool:
	var done := false
	for i in int(seconds / DT):
		done = g.advance(DT) or done
	return done


func test_completes_after_three_seconds() -> void:
	var g := HoldGate.new()
	g.begin()
	check(not _hold(g, 2.9), "not done at 2.9 s")
	check(_hold(g, 0.2), "done by 3.1 s")
	check_near(g.progress(), 1.0, 0.0001, "ring full")
	check(not g.advance(DT), "completion fires once")


func test_early_release_gives_feedback() -> void:
	var g := HoldGate.new()
	g.begin()
	_hold(g, 1.0)
	check(g.release(), "release at 33% is too early")
	check_near(g.progress(), 0.0, 0.0001, "ring resets")


func test_release_after_ninety_percent_is_silent() -> void:
	var g := HoldGate.new()
	g.begin()
	_hold(g, 2.8)
	check(not g.release(), "release at 93% is not an early cancel")


func test_release_after_open_is_silent() -> void:
	var g := HoldGate.new()
	g.begin()
	_hold(g, 3.1)
	check(not g.release(), "release after completion is silent")


func test_idle_gate_ignores_time() -> void:
	var g := HoldGate.new()
	check(not _hold(g, 5.0), "never began")
	check(not g.release(), "nothing to cancel")
