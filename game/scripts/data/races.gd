class_name RaceData
## Playable races and clans of Eorzea, with the body profile used to shape the VRoid bases.
## base: which provided VRoid body is used. ears/tail/horns: extra features.
## scale: overall height multiplier, width: torso/hip breadth, head: head size.

const RACES := {
	"hyur": {"name": "Hyur", "base": "hyur", "clans": ["midlander", "highlander"], "ears": "", "tail": "", "horns": false},
	"elezen": {"name": "Elezen", "base": "hyur", "clans": ["wildwood", "duskwight"], "ears": "long", "tail": "", "horns": false},
	"lalafell": {"name": "Lalafell", "base": "hyur", "clans": ["plainsfolk", "dunesfolk"], "ears": "small", "tail": "", "horns": false},
	"miqote": {"name": "Miqo'te", "base": "miqote", "clans": ["seeker", "keeper"], "ears": "cat", "tail": "cat", "horns": false},
	"roegadyn": {"name": "Roegadyn", "base": "hyur", "clans": ["sea_wolf", "hellsguard"], "ears": "", "tail": "", "horns": false},
	"aura": {"name": "Au Ra", "base": "hyur", "clans": ["raen", "xaela"], "ears": "", "tail": "scaled", "horns": true},
	"hrothgar": {"name": "Hrothgar", "base": "miqote", "clans": ["helion", "the_lost"], "ears": "cat", "tail": "cat", "horns": false},
	"viera": {"name": "Viera", "base": "miqote", "clans": ["rava", "veena"], "ears": "rabbit", "tail": "", "horns": false},
}

const CLANS := {
	"midlander": {"name": "Midlander", "scale": 1.0, "width": 1.0, "head": 1.0, "skin": ["#f3d4c0", "#e8bfa2", "#d9a684", "#b98463", "#8d5e44"]},
	"highlander": {"name": "Highlander", "scale": 1.06, "width": 1.08, "head": 0.98, "skin": ["#e9c2a4", "#cf9d7c", "#b07656", "#8a5740", "#5e3a2a"]},
	"wildwood": {"name": "Wildwood", "scale": 1.12, "width": 0.94, "head": 0.97, "skin": ["#f6e2d4", "#efd2bd", "#e3c0a6", "#d3ad91"]},
	"duskwight": {"name": "Duskwight", "scale": 1.12, "width": 0.94, "head": 0.97, "skin": ["#c9b6b4", "#a99190", "#8b7a80", "#6f6470"]},
	"plainsfolk": {"name": "Plainsfolk", "scale": 0.56, "width": 1.12, "head": 1.45, "skin": ["#f5d7c2", "#eac0a1", "#d8a481"]},
	"dunesfolk": {"name": "Dunesfolk", "scale": 0.56, "width": 1.12, "head": 1.45, "skin": ["#e2b38f", "#c88f68", "#a46a48"]},
	"seeker": {"name": "Seeker of the Sun", "scale": 0.97, "width": 0.97, "head": 1.0, "skin": ["#f3d0b4", "#e0b08b", "#c58f66", "#9c6a46"]},
	"keeper": {"name": "Keeper of the Moon", "scale": 0.97, "width": 0.97, "head": 1.0, "skin": ["#f2e6ea", "#d8c6d2", "#b9a6bd", "#8c7f99"]},
	"sea_wolf": {"name": "Sea Wolf", "scale": 1.22, "width": 1.16, "head": 0.95, "skin": ["#e8c3a8", "#cc9c7c", "#a8775a", "#7d5440"]},
	"hellsguard": {"name": "Hellsguard", "scale": 1.22, "width": 1.16, "head": 0.95, "skin": ["#c9b2a6", "#a48a82", "#7e6d6c", "#5a5058"]},
	"raen": {"name": "Raen", "scale": 0.98, "width": 0.98, "head": 1.0, "skin": ["#f8eee8", "#efdcd2", "#e3cabd"]},
	"xaela": {"name": "Xaela", "scale": 1.03, "width": 1.02, "head": 1.0, "skin": ["#b8a7a0", "#8d7d7a", "#5f5556", "#3c3638"]},
	"helion": {"name": "Helion", "scale": 1.18, "width": 1.2, "head": 1.05, "skin": ["#c9a37c", "#a87f5a", "#8a6443"]},
	"the_lost": {"name": "The Lost", "scale": 1.18, "width": 1.2, "head": 1.05, "skin": ["#9c9a98", "#6f6b6a", "#4a4746"]},
	"rava": {"name": "Rava", "scale": 1.08, "width": 0.95, "head": 0.98, "skin": ["#d8a47e", "#b8825d", "#8f5e3f"]},
	"veena": {"name": "Veena", "scale": 1.08, "width": 0.95, "head": 0.98, "skin": ["#f7e8df", "#ecd6c8", "#dcc1af"]},
}

## Male Au Ra and Roegadyn are notably larger.
const SEX_SCALE := {"aura_m": 1.14, "roegadyn_m": 1.04, "elezen_m": 1.02, "viera_m": 1.04, "hrothgar_m": 1.05}

const HAIRSTYLES := [
	{"id": 0, "name": "Close Crop", "part": ""},
	{"id": 1, "name": "Windswept", "part": "hair_1"},
	{"id": 2, "name": "Flowing Mane", "part": "hair_2"},
]

const HAIR_COLORS := ["#1d1a1a", "#3b2a20", "#6b4a32", "#9a6f45", "#c9a26b", "#e8d5a6", "#f2f0ea", "#9aa3ad",
	"#7a1f1f", "#c0482d", "#e07b39", "#3c5a8a", "#6a3d8f", "#2f6b4f", "#d86ca0", "#4fb3c9"]
const EYE_COLORS := ["#3d2a1c", "#6a4a2a", "#2d5b8a", "#5fa8d8", "#2f7a4a", "#8fc46a", "#c9a227", "#e06a2a", "#a02a2a", "#7a3fa8", "#b0b8c0", "#e8e0c0"]
const LIP_COLORS := ["#b86a6a", "#a04a55", "#d48a8a", "#7a3d4a", "#5a3a3a", "#c06080", "#3a2a3a"]
const FEATURE_COLORS := ["#ffffff", "#e0e8f0", "#c0d8ff", "#202020", "#5a3a2a", "#a0c0a0", "#d0a0e0", "#ff9060"]

const DEITIES := ["Halone, the Fury", "Menphina, the Lover", "Thaliak, the Scholar", "Nymeia, the Spinner",
	"Llymlaen, the Navigator", "Oschon, the Wanderer", "Byregot, the Builder", "Rhalgr, the Destroyer",
	"Azeyma, the Warden", "Nald'thal, the Traders", "Nophica, the Matron", "Althyk, the Keeper"]

const MOONS := ["1st Astral Moon", "1st Umbral Moon", "2nd Astral Moon", "2nd Umbral Moon", "3rd Astral Moon",
	"3rd Umbral Moon", "4th Astral Moon", "4th Umbral Moon", "5th Astral Moon", "5th Umbral Moon",
	"6th Astral Moon", "6th Umbral Moon"]

const VOICES := ["Soft", "Bright", "Calm", "Gruff", "Playful", "Stern"]


static func default_appearance(race := "hyur", clan := "midlander", sex := "f") -> Dictionary:
	return {
		"race": race, "clan": clan, "sex": sex,
		"height": 0.5, "bust": 0.5, "muscle": 0.5,
		"skin": CLANS[clan]["skin"][0], "hair_style": 1, "hair_color": "#3b2a20", "highlights": false,
		"highlight_color": "#c9a26b", "eye_color": "#2d5b8a", "heterochromia": false, "eye_color2": "#2f7a4a",
		"lip_color": "#b86a6a", "feature_color": "#ffffff", "face_paint": 0,
		"tail_length": 0.5, "ear_size": 0.5, "voice": 0,
		"dye_top": "#ffffff", "dye_bottom": "#ffffff",
	}
