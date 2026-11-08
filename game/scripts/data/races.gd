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

## Short lore for the creator, written for this game and faithful to Eorzean history.
const RACE_LORE := {
	"hyur": "The Hyur crossed the seas to Eorzea from the lands around it in three great waves of migration, and today they are the most numerous of its peoples. Of middling height and build, with short rounded ears, they took to the roads on foot and spread far and wide.\n\nTheir many tongues and customs are a gift of that scattered heritage, and the reason no single culture can claim them.",
	"elezen": "Long before the Hyur came, the Elezen ruled the lands of Eorzea. Tall and slender, with long ears and senses keen enough to hear a twig snap across a glade, they once fought bitterly to hold their realm against the newcomers.\n\nOld rivalries have cooled. Elezen now serve in every city-state, most visibly as the knights and nobles of Ishgard.",
	"lalafell": "Small in stature and round of face, the Lalafell first came to Eorzea from the islands of the south seas as farmers and traders. Their size is no measure of their reach: few peoples are as quick of wit or as shrewd at the market.\n\nLalafell can be found in every city, but Ul'dah, built on their trade and coin, is theirs above all.",
	"miqote": "The Miqo'te followed their prey across the frozen sea in the last Age of Ice, and have lived as hunters ever since. Sharp ears and tail grant them a hunter's balance and hearing that few can match.\n\nThey keep to small family groups, and many are wary of crowds. Those who come to the cities often do so alone.",
	"roegadyn": "Towering and broad, the Roegadyn came down from the cold north seas, and their name for themselves means 'people of the sea'. Many have earned their bread as sailors, pirates and mercenaries.\n\nFor all their fearsome size, Roegadyn are known for a calm temper and fierce loyalty to those who earn it.",
	"aura": "The Au Ra hail from the Far East, from the steppe of Othard and the hidden valleys beyond it. Horns frame their heads and smooth scales mark their skin, and their legends say they are children of a father of dawn and a mother of dusk.\n\nFew Au Ra lived in Eorzea until recent years, and many still travel far from their tribes.",
	"hrothgar": "Hailing from the distant isles of Ilsabard, the Hrothgar are powerful, leonine folk whose warrior culture prizes strength and loyalty. Their sharp claws and thick manes make them a striking sight on any Eorzean road.\n\nThough they have lived quietly at the edges of the realm, more Hrothgar now take up the adventurer's life.",
	"viera": "The Viera dwell in the deep forests of Ivalice and the far south, living long lives in close-knit villages. Their long ears catch the faintest sounds, and their legs carry them swiftly through the trees.\n\nViera traditions forbid most from leaving the Wood. Those who do may never return home, and walk the world on their own terms.",
}

const CLAN_LORE := {
	"midlander": "Descended from the third wave of Hyuran settlers, the Midlanders make up most of their people. They settled the fertile lowlands and now fill every guild and market in the realm.",
	"highlander": "The first Hyur to reach Eorzea built their strongholds in the mountains of Gyr Abania. Taller and heavier than their lowland kin, many Highlanders fled to Ul'dah after Ala Mhigo fell and now return to a free homeland.",
	"wildwood": "The Wildwood have kept to the forests for generations. Their sharp eyes and patient archery are the stuff of Gridanian legend, and they are at home among the trees of the Twelveswood.",
	"duskwight": "The Duskwight withdrew into caverns and hollows long ago. Their hearing is keener still than the Wildwood's, and their pale complexions speak of lives spent away from the sun.",
	"plainsfolk": "Plainsfolk farm the fertile plains and lowlands of La Noscea and beyond. Quick-witted and cheerful, they are as comfortable in a ship's rigging as in a field of grain.",
	"dunesfolk": "Dunesfolk crossed the desert sands to settle Thanalan. Sun-browned and sharp-eyed, they built the merchant houses of Ul'dah and still hold many of its purse strings.",
	"seeker": "Seekers of the Sun honour Azeyma, the Warden. They hunt by day, keep their families under a single tribal male called a Nunh, and take a letter of their tribe as a forename prefix.",
	"keeper": "Keepers of the Moon honour Menphina, the Lover. They prefer the hunt by night and live in groups led by their women, keeping old ties with the forest folk of the Black Shroud.",
	"sea_wolf": "Sea Wolves have long sailed the waters around Vylbrand. They are the backbone of Limsa Lominsa's fleets, and many still remember their days as pirates.",
	"hellsguard": "The Hellsguard live in the shadow of the volcanoes of the northern lands, tempered by heat and hardship. Their warrior-monks are renowned for discipline and unbending will.",
	"raen": "The Raen hid themselves in the misty valleys of Doma for centuries. Their scales are pale and their manners gentle, and many find work among the eastern city-states.",
	"xaela": "The Xaela roam the Azim Steppe in dozens of warring tribes. Dark-scaled and fierce, they live by the herd and the hunt, and each tribe honours its own traditions.",
	"helion": "The Helions are the Hrothgar who chose to stay among their kind. They serve their queens with devotion, and their duty to the clan comes before all else.",
	"the_lost": "The Lost are Hrothgar who have left or been cast out of their homeland. They wander far, owing loyalty to no queen, and seek a place of their own in the wide world.",
	"rava": "The Rava make their homes in the hot southern jungles. Sun-kissed and agile, they hunt beneath the dense canopy and guard their villages from the beasts that roam it.",
	"veena": "The Veena dwell in cooler northern forests like the Golmore and the Skatay Range. Pale-skinned and serene, they watch over the deep woods that nurture them.",
}

## Appearance features in creator order. "races" limits a feature to some races; "sex" to one sex.
## kind: slider, palette, types (named options with portraits), hair (hairstyle portraits).
const FEATURES := [
	{"key": "height", "name": "Height", "kind": "slider"},
	{"key": "muscle", "name": "Muscle Tone", "kind": "slider"},
	{"key": "bust", "name": "Bust Size", "kind": "slider", "sex": "f"},
	{"key": "tail_length", "name": "Tail Length", "kind": "slider", "races": ["miqote", "aura", "hrothgar"]},
	{"key": "face", "name": "Face", "kind": "types", "face": true},
	{"key": "skin", "name": "Skin Color", "kind": "palette"},
	{"key": "hair_style", "name": "Hairstyle", "kind": "hair", "face": true},
	{"key": "hair_color", "name": "Hair Color", "kind": "palette", "face": true},
	{"key": "eye_shape", "name": "Eye Shape", "kind": "types", "face": true},
	{"key": "iris", "name": "Iris Size", "kind": "types", "face": true},
	{"key": "eye_color", "name": "Eye Color", "kind": "palette", "face": true},
	{"key": "brows", "name": "Eyebrows", "kind": "types", "face": true},
	{"key": "mouth", "name": "Mouth", "kind": "types", "face": true},
	{"key": "lip_color", "name": "Lip Color", "kind": "palette", "face": true},
	{"key": "fangs", "name": "Fangs", "kind": "types", "face": true, "races": ["miqote", "hrothgar", "aura", "viera", "roegadyn"]},
	{"key": "ear_size", "name": "Ear Length", "kind": "slider", "races": ["elezen", "miqote", "hrothgar", "viera"], "face": true},
	{"key": "ear_size", "name": "Horn Size", "kind": "slider", "races": ["aura"], "face": true},
	{"key": "feature_color", "name": "Scale & Horn Color", "kind": "palette", "races": ["aura", "hrothgar"], "face": true},
	{"key": "facial_feature", "name": "Facial Features", "kind": "types", "face": true},
	{"key": "tattoo", "name": "Tattoos", "kind": "types", "face": true},
	{"key": "tattoo_color", "name": "Tattoo Color", "kind": "palette", "face": true},
	{"key": "face_paint", "name": "Face Paint", "kind": "types", "face": true},
	{"key": "paint_color", "name": "Face Paint Color", "kind": "palette", "face": true},
	{"key": "voice", "name": "Voice", "kind": "types"},
]

const FACE_TYPES := ["Type 1", "Type 2", "Type 3", "Type 4"]
const EYE_SHAPES := ["Natural", "Sharp", "Gentle", "Wide", "Round", "Narrow"]
const IRIS_SIZES := [["Large", 1.0], ["Small", 0.84]]
const BROWS := ["Natural", "Furrowed", "Raised", "Soft", "Arched"]
const MOUTHS := ["Natural", "Small", "Wide", "Upturned", "Stern"]
const FANGS := ["None", "Small", "Pronounced", "Long", "Sabre"]
const FACIAL_FEATURES := ["None", "Freckles", "Beauty Mark", "Scar", "Scales", "Whisker Marks"]
const TATTOOS := ["None", "Temple Lines", "Eye Rings", "Chin Lines", "Temple Swirl", "Cheek Dots"]
const FACE_PAINTS := ["None", "Cheek Stripes", "Eye Mask", "Tear Lines", "Forehead Mark", "War Paint"]

const HAIRSTYLES := [
	{"id": 0, "name": "Close Crop", "part": ""},
	{"id": 1, "name": "Windswept", "part": "hair_1"},
	{"id": 2, "name": "Flowing Mane", "part": "hair_2"},
]

const HAIR_COLORS := ["#1d1a1a", "#3b2a20", "#6b4a32", "#9a6f45", "#c9a26b", "#e8d5a6", "#f2f0ea", "#9aa3ad",
	"#7a1f1f", "#c0482d", "#e07b39", "#3c5a8a", "#6a3d8f", "#2f6b4f", "#d86ca0", "#4fb3c9"]
const EYE_COLORS := ["#3d2a1c", "#6a4a2a", "#2d5b8a", "#5fa8d8", "#2f7a4a", "#8fc46a", "#c9a227", "#e06a2a", "#a02a2a", "#7a3fa8", "#b0b8c0", "#e8e0c0"]

const DEITIES := ["Halone, the Fury", "Menphina, the Lover", "Thaliak, the Scholar", "Nymeia, the Spinner",
	"Llymlaen, the Navigator", "Oschon, the Wanderer", "Byregot, the Builder", "Rhalgr, the Destroyer",
	"Azeyma, the Warden", "Nald'thal, the Traders", "Nophica, the Matron", "Althyk, the Keeper"]

const DEITY_LORE := [
	"Goddess of war, honoured above all others in Ishgard. Her sign is the shield, and her faithful are expected to stand their ground.",
	"Goddess of love and the moons, ever chasing her sister Azeyma across the sky. She watches over devotion and longing.",
	"God of knowledge and rivers, keeper of all that is learned. Scholars and sages beg his favour before their studies.",
	"Goddess of the stars and the spinning wheel, who weaves the threads of fate. Her followers believe nothing happens by chance.",
	"Goddess of the sea and the winds, beloved of every sailor in Limsa Lominsa. She guides those who trust the tides.",
	"God of wanderers and the mountains, patron of travellers and those who sleep under the open sky.",
	"God of crafts and invention, favoured by smiths and builders who shape the world with their hands.",
	"God of destruction and change, whose falling stars level what must make way for the new. Revered in Ala Mhigo.",
	"Goddess of the sun and of oaths, watching over those who keep their word. Revered by the Seekers of the Sun.",
	"Twin gods of commerce and the underworld, who weigh coin and soul alike. Ul'dah is built in their name.",
	"Goddess of the harvest and plenty. Farmers of the Black Shroud leave her offerings at every sowing.",
	"God of time and the earth, steady and patient as the turning of the ages.",
]

const MOONS := ["1st Astral Moon", "1st Umbral Moon", "2nd Astral Moon", "2nd Umbral Moon", "3rd Astral Moon",
	"3rd Umbral Moon", "4th Astral Moon", "4th Umbral Moon", "5th Astral Moon", "5th Umbral Moon",
	"6th Astral Moon", "6th Umbral Moon"]

const VOICES := ["Soft", "Bright", "Calm", "Gruff", "Playful", "Stern"]

## Where each starting city's story begins, for the job screen.
const CITY_LORE := {
	"gridania": "Deep in the Black Shroud, Gridania lives in an uneasy peace with the elementals of the forest.",
	"limsa": "Built on the cliffs of Vylbrand, Limsa Lominsa is a city of admirals, merchants and reformed pirates.",
	"uldah": "Rising from the sands of Thanalan, Ul'dah is a city of gold, where coin buys almost anything.",
	"ishgard": "High in the snows of Coerthas, Ishgard has opened its gates at last after a thousand years of war.",
}


static func default_appearance(race := "hyur", clan := "midlander", sex := "f") -> Dictionary:
	return {
		"race": race, "clan": clan, "sex": sex,
		"height": 0.5, "bust": 0.5, "muscle": 0.5,
		"skin": CLANS[clan]["skin"][0], "hair_style": 1, "hair_color": "#3b2a20", "highlights": false,
		"highlight_color": "#c9a26b", "eye_color": "#2d5b8a", "heterochromia": false, "eye_color2": "#2f7a4a",
		"lip_color": "#b86a6a", "feature_color": "#ffffff", "face_paint": 0, "paint_color": "#8a1a1a",
		"tattoo": 0, "tattoo_color": "#24304a", "facial_feature": 0,
		"face": 0, "eye_shape": 0, "iris": 0, "brows": 0, "mouth": 0, "fangs": 0,
		"tail_length": 0.5, "ear_size": 0.5, "voice": 0,
		"dye_top": "#ffffff", "dye_bottom": "#ffffff",
	}


## Option names for a "types" feature.
static func options(key: String) -> Array:
	match key:
		"face": return FACE_TYPES
		"eye_shape": return EYE_SHAPES
		"iris": return IRIS_SIZES.map(func(o): return o[0])
		"brows": return BROWS
		"mouth": return MOUTHS
		"fangs": return FANGS
		"facial_feature": return FACIAL_FEATURES
		"tattoo": return TATTOOS
		"face_paint": return FACE_PAINTS
		"voice": return VOICES
	return []


## Colour grid for a palette feature, laid out like the in-game picker (8 columns).
static func palette(key: String, clan: String) -> Array:
	match key:
		"skin": return _skin_grid(CLANS[clan]["skin"])
		"hair_color", "highlight_color": return _hue_grid(24, 0.25, 0.92)
		"eye_color", "eye_color2": return _hue_grid(12, 0.35, 0.85)
		"lip_color": return _ramp_grid(["#f0b0b0", "#d07080", "#a04a55", "#7a3d4a", "#c06080", "#9a6a8a", "#5a3a3a", "#3a2a3a"], 6)
		"feature_color", "tattoo_color", "paint_color": return _hue_grid(16, 0.2, 0.95)
	return HAIR_COLORS


## Rows run light to dark through the clan's skin tones; columns shift from warm to cool.
static func _skin_grid(tones: Array) -> Array:
	var out := []
	var rows := 12
	for r in rows:
		var t := float(r) / (rows - 1) * (tones.size() - 1)
		var i := mini(int(t), tones.size() - 2)
		var base := Color(tones[i]).lerp(Color(tones[i + 1]), t - i)
		for c in 8:
			var k := (float(c) / 7.0 - 0.5)
			var col := Color.from_hsv(fposmod(base.h - k * 0.03, 1.0), clampf(base.s * (1.0 + k * 0.5), 0.0, 1.0), base.v * (1.0 - absf(k) * 0.06))
			out.append("#" + col.to_html(false))
	return out


## A full spectrum: each row is a hue family from pale to deep, plus a grey row.
static func _hue_grid(rows: int, vmin: float, vmax: float) -> Array:
	var out := []
	for r in rows - 1:
		# Pale golds first, then oranges and reds, through violet and blue to green.
		var h := fposmod(0.14 - float(r) / (rows - 1) * 0.86, 1.0)
		var sat := 0.55 if r % 2 == 0 else 0.8
		for c in 8:
			var t := float(c) / 7.0
			out.append("#" + Color.from_hsv(h, lerpf(sat * 0.35, sat, t), lerpf(vmax, vmin, t)).to_html(false))
	for c in 8:
		out.append("#" + Color.from_hsv(0.0, 0.0, lerpf(0.97, 0.06, float(c) / 7.0)).to_html(false))
	return out


static func _ramp_grid(cols: Array, rows: int) -> Array:
	var out := []
	for r in rows:
		for c in cols:
			out.append("#" + Color(c).lerp(Color.WHITE if r < rows / 2 else Color.BLACK, absf(r - rows / 2.0 + 0.5) / rows * 0.8).to_html(false))
	return out
