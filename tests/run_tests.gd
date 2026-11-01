extends SceneTree
## Runs every tests/test_*.gd suite headless:
##   godot --headless --path . -s tests/run_tests.gd
## Exit code is 1 when any test fails.


func _initialize() -> void:
	var total := 0
	var failed := 0
	for file in DirAccess.get_files_at("res://tests"):
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var suite: TestCase = load("res://tests/" + file).new()
		for method in suite.get_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			total += 1
			suite.failures.clear()
			suite.call(test_name)
			if suite.failures.is_empty():
				print("  ok    %s :: %s" % [file, test_name])
			else:
				failed += 1
				print("  FAIL  %s :: %s — %s" % [file, test_name, "; ".join(suite.failures)])
	print("%d/%d tests passed" % [total - failed, total])
	quit(1 if failed > 0 else 0)
