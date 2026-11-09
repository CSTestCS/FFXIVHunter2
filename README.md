# Eorzea Hunter: Echoes of an Adventurer

An unofficial fan game set in the world of FINAL FANTASY XIV after Endwalker. It plays like Monster Hunter and Elden Ring: stamina-based action combat with weapon-style movesets, telegraphed heavy-hitting monsters, meals before a hunt, and gear progression. FINAL FANTASY is a registered trademark of Square Enix. This project is not affiliated with or endorsed by Square Enix.

## Play

**[Download EorzeaHunter-Windows.zip](https://github.com/CSTestCS/FFXIVHunter2/raw/claude/affectionate-ritchie-g7jiwu/EorzeaHunter-Windows.zip)** (47 MB, one file).

1. Unzip it anywhere.
2. Double-click `EorzeaHunter.exe` (Windows 10/11, 64-bit).
3. If you only see a black screen, close the game and double-click `Play in Safe Mode (OpenGL).bat` instead.

The game picks a graphics API automatically: Vulkan first, then Direct3D 12, then OpenGL. Saves, settings and logs are stored in `%APPDATA%\EorzeaHunter\` (the log is `logs\godot.log`). There are 8 independent save slots.

## Controls

| Action | Keyboard / Mouse | Gamepad |
|---|---|---|
| Move / Camera | WASD / Mouse | Left stick / Right stick |
| Light attack (combo) | Left click | RB |
| Heavy attack (hold to charge where available) | Right click | RT |
| Weapon skill | Q | LT |
| Guard (tap just before a hit for Perfect Guard) | Ctrl | LB |
| Dodge roll (tap) / Sprint (hold) | Space | B |
| Jump | F | A |
| Interact / Talk / Carve | E | A |
| Quick item (set in Items menu) | R | X |
| Lock-on / switch target | Tab or middle mouse | R3 |
| Job actions 1-4 | 1-4 | D-pad |
| Menu / Journal / Map compass | Esc / J | Start / Back |
| Swimming: dive / surface | Ctrl / F | LB / A |

Menus are fully navigable with a gamepad; switch tabs with Z/X or LB/RB.

## What is in the game

- **Character creation laid out like FFXIV's own**: Race & Gender, Clan, Appearance, Job and city-state, Nameday & Guardian, and Name, over a starry aetherial sea or four other environments (La Noscea, the Black Shroud, Thanalan, an inn room) with a time-of-day toggle, pose and attire previews, and a free camera. All 8 races and 16 clans, with height, muscle, bust, tail, face type, skin, hairstyle, hair colour and highlights, eye shape, iris size, eye colour and heterochromia, eyebrows, mouth, lip colour, fangs, ear/horn size, scale colour, facial features, tattoos, face paint and voice. Colour grids and portrait grids work as in the original. A second pass customises the legendary **Warrior of Light** NPC (appearance, name and job), who appears in cutscenes.
- **19 jobs, all available from the start** (PLD, WAR, DRK, GNB, WHM, SCH, AST, SGE, MNK, DRG, NIN, SAM, RPR, BRD, MCH, DNC, BLM, SMN, RDM). Each plays as a distinct weapon type with a light combo chain, heavy branches, charge attacks, a weapon skill, a job gauge and four cooldown job actions (for example, Samurai Sen into Iaijutsu, Gunbreaker cartridges into Gnashing Fang, Dragoon Jump with i-frames, Bard charged Apex Arrow, Black Mage Astral Fire / Umbral Ice).
- **Your story begins outside the city tied to your job**: Gridania, Limsa Lominsa, Ul'dah or Ishgard (Foundation). You wake on the road, robbed and battered, and a villager brings you into the city. The 22-quest main scenario, in three acts (The Road Back, The Gilded Fangs, The Unsung), keeps you a mere adventurer alongside an original supporting cast: a retired adventurer mentor, a merchant, a rival-turned-friend and an aetherologist. Scions of the Seventh Dawn appear only at turning points (Alphinaud and Alisaie, Y'shtola, and Estinien with the Warrior of Light), and Krile appears in a side quest. 34 cutscenes, with a conversation camera that varies its angles line by line (close-ups, over-the-shoulder, two-shots, profiles, low and high angles) and drifts slowly while characters speak.
- **Gridania as one city**: New Gridania and Old Gridania are joined by three walk-through tunnels in the rock ridge between them (no loading, no teleport orbs). The area title changes as you pass from one half to the other.
- **21 zones connected as in FFXIV**: the four cities, the Black Shroud (Central, East, South, North), La Noscea (Middle, Lower, Eastern, Western, Upper, Outer), Thanalan (Western, Central, Eastern, Southern, Northern), Coerthas Central Highlands and Mor Dhona, plus the Limsa to Vesper Bay ferry and aetheryte teleports.
- **Quests and guildleves**: small hunts, large monster hunts, gathering, defense against waves, and escorts. Quests carry story and better rewards; leves are repeatable contracts. Missions use a Monster Hunter-style camp, a supply box and a three-faint limit.
- **Meals**: one main dish (offence and vitality), one side (defence and resistances) and one drink (stamina, MP and swimming), lasting one outing.
- **Monsters** with unique telegraphed movesets, enrage phases, part breaks, toppling and carving: Coeurl, Morbol, Great Pugil, Adamantoise, Wyvern, Behemoth, a bandit chief and 15 smaller species.
- **Progression**: levels (to 90), gil, weapon tiers (Weathered to Adamantite), four armour slots with dyes, materia crafting and melding, new jobs from the trainer, and party members recruited at the guild who fight by role, heal and dodge telegraphs.
- **Elden Ring touches**: stamina-gated combat, i-frame rolls and backsteps, perfect guards, aetherytes that work like Sites of Grace (rest to heal, respawn foes and save), and gil dropped where you fall that you can recover once.
- **Swimming and diving** with a breath meter, in seas, lakes and rivers.
- **Expressive faces**: VRoid expressions and A/I/U/E/O visemes; mouths follow dialogue as it types, and expressions match each scene.
- **Interactive inventory**: use items, set the quick item, discard materials, meld materia, show or hide armour pieces. Optional hiding of sheathed weapons.

## Performance design

- Static city and camp geometry is merged per material (a few draw calls per area). Trees, rocks and grass use chunked MultiMeshes with visibility ranges.
- Hair, ears, tails and hats follow a single bone, so they are attached rigidly rather than GPU-skinned. Only body clothing is skinned.
- Animations are generated once per skeleton and played by Godot's native AnimationPlayer. Distant NPCs and monsters pause their animation and AI.
- Textures are GPU-compressed (BC/S3TC) with mipmaps and de-duplicated across models. Body skin is never culled or removed.
- No audio files ship: sounds and ambient music are synthesised once and cached.
- Graphics presets (Low / Medium / High / Ultra) toggle shadows, SSAO, SSIL, SSR, volumetric fog, skin subsurface scattering, draw distance and grass density.

## Credits

- Fonts: Barlow Semi Condensed and Cinzel, under the SIL Open Font License (see `game/assets/fonts/`).

## Building from source

- Engine: Godot 4.5.1 stable (Forward+, with automatic fallback to the OpenGL Compatibility renderer). Open `game/` in the editor, or export headless:
  `godot --headless --path game --export-release "Windows Desktop" ../dist/EorzeaHunter.exe` (the game data is embedded in the exe)
- Character assets in `game/assets/characters/` are generated from the provided VRoid `.vrm` files with `tools/vrm_split.py`:
  `python3 tools/vrm_split.py <folder with .vrm files> game/assets/characters`
  The tool keeps each base body intact, isolates hair from the hairstyle samples and clothing items from the clothing samples (the sample bodies are dropped), rebinds every part to the standard humanoid bones, converts MToon toon materials to physically based ones, and writes shared, downscaled textures.

## Known limitations

- Elezen, Lalafell, Roegadyn, Au Ra, Hrothgar and Viera are shaped from the two provided base bodies (Hyur and Miqo'te) with proportion changes and procedural ears, horns and tails. They are approximations until dedicated models are added.
- Two hairstyles are provided (plus a close crop) and one clothing set, which is tinted per armour tier and dye.
- The creator has no Jaw or Nose options: the VRoid faces have no shape keys for them.
- Cities and regions are stylised layouts built around their real landmarks, names and connections. They are not one-to-one copies of the FFXIV maps.
- The Windows exe was tested under Wine with software Vulkan and OpenGL drivers (both reach the title screen with no errors), and the gameplay test suites ran on the Linux build. It has not been run on real Windows GPU hardware here.
