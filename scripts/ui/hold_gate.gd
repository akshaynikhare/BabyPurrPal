class_name HoldGate
extends RefCounted
## Parent gate timing: fills over HOLD_SEC; releasing under CANCEL_FRACTION is a "too early" release.

const HOLD_SEC := 3.0
const CANCEL_FRACTION := 0.9

var elapsed := 0.0
var holding := false
var completed := false


func begin() -> void:
	elapsed = 0.0
	holding = true
	completed = false


func progress() -> float:
	return clampf(elapsed / HOLD_SEC, 0.0, 1.0)


## Returns true on the frame the hold completes.
func advance(delta: float) -> bool:
	if not holding or completed:
		return false
	elapsed += delta
	if elapsed >= HOLD_SEC:
		completed = true
		return true
	return false


## Returns true when the release deserves "keep holding" feedback.
func release() -> bool:
	var too_early := holding and not completed and progress() < CANCEL_FRACTION
	holding = false
	elapsed = 0.0
	return too_early
