extends TestCase


func _make() -> ToyBar:
	var bar := ToyBar.new()
	# Not in the tree: build it by hand.
	bar._ready()
	return bar


func _locked(bar: ToyBar) -> bool:
	var all := true
	for b: RoundButton in bar._buttons:
		all = all and b.disabled
	return all


func test_session_locks_and_unlocks_the_bar() -> void:
	var bar := _make()
	check(not _locked(bar), "starts unlocked")
	EventBus.toy_started.emit(&"milk")
	check(_locked(bar), "locked on start")
	check_near(bar._buttons[1].modulate.a, RoundButton.DISABLED_ALPHA, 0.0001, "dimmed")
	check_near(bar._labels[2].modulate.a, RoundButton.DISABLED_ALPHA, 0.0001, "label dimmed")
	EventBus.toy_finished.emit(&"milk")
	check(not _locked(bar), "unlocked on finish")
	check_near(bar._buttons[1].modulate.a, 1.0, 0.0001, "full colour again")
	bar.free()


func test_lock_survives_a_pet_change() -> void:
	var bar := _make()
	EventBus.toy_started.emit(&"bone")
	bar.set_pet(2)
	check(_locked(bar), "still locked with the new pet's toys")
	check_eq(bar._toys[0].id, &"carrot", "icons still follow the pet")
	EventBus.toy_finished.emit(&"bone")
	check(not _locked(bar), "unlocked")
	bar.free()


func test_locked_buttons_ignore_presses() -> void:
	var bar := _make()
	var presses := [0]
	bar._buttons[0].pressed.connect(func() -> void: presses[0] += 1)
	bar.set_locked(true)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	bar._buttons[0]._gui_input(touch)
	check_eq(presses[0], 0, "no press while locked")
	check(not bar._buttons[0]._tap.is_down(), "press not tracked")
	bar.free()
