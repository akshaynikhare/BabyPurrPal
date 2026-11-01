extends TestCase


func test_every_pet_has_three_unique_toys() -> void:
	var seen := {}
	for pet in 3:
		var toys := ToyCatalog.toys_for(pet)
		check_eq(toys.size(), 3, "pet %d toy count" % pet)
		for toy: Dictionary in toys:
			check(not seen.has(toy.id), "unique id %s" % toy.id)
			seen[toy.id] = true


func test_pet_to_toy_mapping() -> void:
	check_eq(ToyCatalog.toys_for(0)[0].id, &"milk", "cat first toy")
	check_eq(ToyCatalog.toys_for(1)[1].label, "Tennis Ball", "dog second toy")
	check_eq(ToyCatalog.toys_for(2)[2].id, &"bell", "rabbit third toy")
	check_eq(ToyCatalog.toys_for(3)[0].id, &"milk", "index wraps")
	check_eq(ToyCatalog.toys_for(-1)[0].id, &"carrot", "negative index wraps")


func test_name_drops_emoji() -> void:
	check_eq(ToyCatalog.clean_name("Kitty Cat \U01F431"), "Kitty Cat", "emoji stripped")
	check_eq(ToyCatalog.clean_name("Puppy Dog"), "Puppy Dog", "plain name kept")


func test_safe_insets_scale_to_viewport() -> void:
	var insets := UiLayout.safe_insets(Rect2i(0, 100, 1080, 2200), Vector2i(1080, 2400), Vector2(720, 1600))
	check_near(insets.x, 0.0, 0.01, "left")
	check_near(insets.y, 100.0 * 720.0 / 1080.0, 0.01, "top scaled")
	check_near(insets.w, 100.0 * 720.0 / 1080.0, 0.01, "bottom scaled")
	check_eq(UiLayout.safe_insets(Rect2i(), Vector2i.ZERO, Vector2(720, 1600)), Vector4.ZERO, "no screen")
