class_name UiStyle
extends RefCounted
## Shared palette and StyleBox helpers so code-built controls match ui_theme.tres.

const CREAM := Color("FFF4E0")
const BROWN := Color("7A5233")
const TEXT := Color("5E3B1F")
const MINT := Color("CDEFD9")
const SKY := Color("D6ECFF")
const PEACH := Color("FFE1C7")
const PINK := Color("FFD6E0")
const AMBER := Color("FFD27A")
const BLUE := Color("A9D4FF")
const SHADOW := Color(0.478, 0.322, 0.2, 0.3)

const SHADOW_OFFSET := 6
const BORDER := 5
const TOUCH_MIN := 96.0


static func box(fill: Color, radius := 28, border := BORDER, shadow := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = BROWN
	sb.anti_aliasing = true
	if shadow:
		sb.shadow_color = SHADOW
		sb.shadow_size = 1
		sb.shadow_offset = Vector2(0, SHADOW_OFFSET)
	return sb
