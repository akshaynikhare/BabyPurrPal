extends TestCase

const DT := 1.0 / 60.0


func _run(m: MouthFollower, env: float, frames: int) -> float:
	var v := 0.0
	for i in frames:
		v = m.update(env, DT)
	return v


func test_hysteresis() -> void:
	var m := MouthFollower.new()
	check_near(_run(m, 0.15, 30), 0.0, 0.0001, "between thresholds stays closed")
	check(_run(m, 0.5, 30) > 0.3, "opens above open threshold")
	check(m.is_open, "open")
	check(_run(m, 0.15, 30) > 0.0, "between thresholds stays open")
	check(m.is_open, "still open")
	_run(m, 0.05, 1)
	check(not m.is_open, "closes below close threshold")
	check(_run(m, 0.05, 60) < 0.01, "settles closed")


func test_smoothing() -> void:
	var m := MouthFollower.new()
	var first := m.update(1.0, DT)
	check(first > 0.0 and first < 1.0, "first step is partial, got %s" % first)
	var prev := first
	var monotonic := true
	for i in 30:
		var v := m.update(1.0, DT)
		monotonic = monotonic and v >= prev
		prev = v
	check(monotonic, "rises monotonically")
	check_near(prev, 1.0, 0.01, "reaches full open")


func test_frame_rate_independent() -> void:
	var a := MouthFollower.new()
	var b := MouthFollower.new()
	_run(a, 0.8, 60)
	for i in 30:
		b.update(0.8, DT * 2.0)
	check_near(a.value, b.value, 0.01, "30 fps matches 60 fps")


func test_response_curve_widens_small_openings() -> void:
	var m := MouthFollower.new()
	var v := _run(m, 0.3, 120)
	var linear := (0.3 - m.close_threshold) / (1.0 - m.close_threshold)
	check(v > linear, "exponent < 1 lifts quiet syllables (%s > %s)" % [v, linear])
