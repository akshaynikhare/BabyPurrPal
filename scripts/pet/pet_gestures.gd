class_name PetGestures
extends RefCounted
## Pure gesture rules, in 720×1600 base-unit pixels.

enum Swipe { NONE, NEXT, PREVIOUS }
enum Pinch { NONE, ZOOM_IN, ZOOM_OUT }

const SWIPE_MIN_DX := 45.0
const SWIPE_DOMINANCE := 1.2
const SWIPE_MAX_MS := 800
const PINCH_IN_RATIO := 1.22
const PINCH_OUT_RATIO := 0.82
## A press on the pet within TAP_SLOP is a tap once released. Held, it is a tap
## at TAP_HOLD_MS if it has barely moved, or at STROKE_MIN_MS if it only crept.
const TAP_SLOP := 24.0
const TAP_STILL := 10.0
const TAP_HOLD_MS := 140
## Petting: a drag over the pet at least this long, slower on average than a swipe.
const STROKE_MIN_MS := 250
const STROKE_MAX_SPEED := 450.0


## Swiping left shows the next pet, right the previous one.
static func classify_swipe(delta: Vector2, duration_ms: int) -> Swipe:
	if duration_ms >= SWIPE_MAX_MS:
		return Swipe.NONE
	if absf(delta.x) <= SWIPE_MIN_DX or absf(delta.x) <= absf(delta.y) * SWIPE_DOMINANCE:
		return Swipe.NONE
	return Swipe.NEXT if delta.x < 0.0 else Swipe.PREVIOUS


## ratio = current finger distance / distance when the pinch (or last change) began.
static func classify_pinch(ratio: float) -> Pinch:
	if ratio > PINCH_IN_RATIO:
		return Pinch.ZOOM_IN
	if ratio < PINCH_OUT_RATIO:
		return Pinch.ZOOM_OUT
	return Pinch.NONE


## moved = farthest the finger got from where it pressed. A finger already
## creeping waits longer, so the start of a slow stroke is not taken for a tap.
static func is_tap(moved: float, held_ms: int, released: bool) -> bool:
	if moved > TAP_SLOP:
		return false
	return released or held_ms >= STROKE_MIN_MS or (held_ms >= TAP_HOLD_MS and moved <= TAP_STILL)


## path = total distance travelled. Average speed, so a quick swipe never qualifies.
static func is_stroke(held_ms: int, moved: float, path: float, over_pet: bool) -> bool:
	if not over_pet or held_ms < STROKE_MIN_MS or moved <= TAP_SLOP:
		return false
	return path * 1000.0 / held_ms <= STROKE_MAX_SPEED
