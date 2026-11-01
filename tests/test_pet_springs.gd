extends TestCase


func test_follow_spring_settles_without_overshoot() -> void:
	var state := Vector2.ZERO
	var peak := 0.0
	for i in 60:
		state = HeadLook.spring(state, 1.0, HeadLook.FOLLOW_OMEGA, 1.0 / 60.0)
		peak = maxf(peak, state.x)
	check(peak <= 1.0, "no overshoot, peak %f" % peak)
	check_near(state.x, 0.98, 0.02, "about there after 1 s")


func test_follow_spring_survives_a_long_frame() -> void:
	var state := HeadLook.spring(Vector2.ZERO, 1.0, HeadLook.FOLLOW_OMEGA, 2.0)
	check(state.x > 0.9 and state.x <= 1.0, "big step lands near the target, got %f" % state.x)


func test_squash_peaks_near_its_amount_then_overshoots_and_settles() -> void:
	var state := Vector2(0.0, 0.1 * BodyBounce.SQUASH_KICK)
	var squash := 0.0
	var stretch := 0.0
	var t := 0.0
	while t < 0.5:
		state = BodyBounce.step(state, BodyBounce.SQUASH_OMEGA, BodyBounce.SQUASH_DAMPING, 1.0 / 60.0)
		t += 1.0 / 60.0
		squash = maxf(squash, state.x)
		stretch = minf(stretch, state.x)
	check_near(squash, 0.1, 0.02, "peak squash")
	check(stretch < -0.01, "overshoots into a stretch, %f" % stretch)
	check(absf(state.x) < 0.01, "settled by 0.5 s, %f" % state.x)
