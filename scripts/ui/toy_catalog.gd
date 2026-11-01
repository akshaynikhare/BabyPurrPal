class_name ToyCatalog
extends RefCounted
## Toys per pet index (cat, dog, rabbit). `id` is both the toy_used payload and the drawn icon.

const TOYS: Array = [
	[
		{"id": &"milk", "label": "Warm Milk", "fill": UiStyle.SKY},
		{"id": &"fish", "label": "Fish Snack", "fill": UiStyle.PEACH},
		{"id": &"yarn", "label": "Yarn Ball", "fill": UiStyle.PINK},
	],
	[
		{"id": &"bone", "label": "Juicy Bone", "fill": UiStyle.PEACH},
		{"id": &"ball", "label": "Tennis Ball", "fill": UiStyle.MINT},
		{"id": &"water", "label": "Fresh Water", "fill": UiStyle.SKY},
	],
	[
		{"id": &"carrot", "label": "Crunchy Carrot", "fill": UiStyle.PEACH},
		{"id": &"clover", "label": "Sweet Clover", "fill": UiStyle.MINT},
		{"id": &"bell", "label": "Silver Bell", "fill": UiStyle.PINK},
	],
]

const PET_FACES: Array[StringName] = [&"pet_cat", &"pet_dog", &"pet_rabbit"]
const DEFAULT_NAMES: Array[String] = ["Kitty Cat", "Puppy Dog", "Bunny Rabbit"]


static func toys_for(pet_index: int) -> Array:
	return TOYS[posmod(pet_index, TOYS.size())]


static func face_for(pet_index: int) -> StringName:
	return PET_FACES[posmod(pet_index, PET_FACES.size())]


## Pet names may arrive with emoji; the UI draws icons instead of relying on an emoji font.
static func clean_name(raw: String) -> String:
	var out := ""
	for i in raw.length():
		if raw.unicode_at(i) < 0x2000:
			out += raw[i]
	return out.strip_edges()
