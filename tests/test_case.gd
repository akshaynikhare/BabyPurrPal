class_name TestCase
extends RefCounted
## Base class for headless logic tests. Methods named test_* are run by tests/run_tests.gd.

var failures: PackedStringArray = []


func check(condition: bool, message := "check failed") -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message := "") -> void:
	if actual != expected:
		failures.append("%s expected %s, got %s" % [message, expected, actual])


func check_near(actual: float, expected: float, tolerance := 0.0001, message := "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s expected %s ± %s, got %s" % [message, expected, tolerance, actual])
