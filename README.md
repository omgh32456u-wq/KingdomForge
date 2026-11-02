# KingdomForge

An original medieval kingdom-management game (Godot 4.7.2, GDScript, GL Compatibility renderer),
inspired by the economic depth of classic castle-builders. Offline, single-player vertical slice.

> **Status: untested prototype.** The code was written without access to a Godot editor, so it has
> **never been opened, imported, run, or exported**. Expect to fix a few GDScript errors on first
> launch. See "Known limitations".

## Open and run
1. Install Godot 4.7.2 (standard, non-.NET build).
2. Import `project.godot` and let the editor finish importing (this also builds the `class_name` cache).
3. Press F5. The main scene is `scenes/main.tscn`.

Optional logic checks: `godot --headless --import`, then `godot --headless --script tests/run_checks.gd`
(prints PASS/FAIL lines; not yet run).

## Controls
| Action | Touch | Mouse / keyboard |
|---|---|---|
| Pan | one-finger drag | left drag, WASD / arrows |
| Zoom | pinch | wheel |
| Rotate | two-finger twist | Q / E, right-drag (also tilts) |
| Pick building | bottom bar | bottom bar |
| Position ghost | tap terrain | hover / click |
| Place | tap the same spot again, or "Build" | click same spot, or "Build" |
| Select / demolish | tap a building, then Demolish (50% refund) | same |

## Implemented gameplay
- 96 m procedural terrain with hills, a river, forests (MultiMesh) and rocks. Water, steep slopes, trees and rocks block building.
- Grid placement with a green/red ghost showing the real model and footprint.
- 9 buildings: Keep (pre-placed), House, Farm, Woodcutter, Quarry, Granary, Watchtower, Barracks, Chapel.
- Economy tick ("day" = 5 s; Pause/1x/3x): production scaled by staffing and mood, food consumption, tax income,
  storage cap (300 + 200 per granary), population growth limited by housing, starvation and emigration.
- Decisions: tax level (5 steps) and ration level (3 steps) change gold, food use and happiness; the Kingdom panel shows the happiness breakdown.
- Defense: towers and recruited soldiers (barracks capacity, gold upkeep) vs. periodic raids announced two days ahead. Raids are resolved numerically with consequences; there are no animated raiders.
- Save/Load to `user://kingdomforge_save.json`, autosave every 10 days.

## Known limitations
- **Not validated in an engine** (see above). Camera twist direction and touch tuning are unverified on a device.
- Models are procedural low-poly assemblies built in GDScript (`scripts/building_factory.gd`). **No Blender files, GLB assets, or Blender pipeline are included.**
- Roughly 10-25 mesh nodes per building and no batching; large towns may be heavy on mid-range phones.
- No sound, no animated units/villagers, no multiplayer (the Economy class is UI-independent to help later networking).
- No Android export preset is committed (it needs your keystore).

## Android export prerequisites
Android SDK + platform-tools, JDK 17, Godot Android build template (Project > Install Android Build Template),
Android export templates for 4.7.2, a debug/release keystore, and ETC2/ASTC import (already enabled in `project.godot`).
Orientation is locked to sensor-landscape.

## Layout
`scripts/defs.gd` data and balance - `economy.gd` rules - `world.gd` terrain/placement - `building_factory.gd` models -
`camera_rig.gd` input/camera - `hud.gd` UI - `main.gd` wiring - `save_system.gd` persistence - `tests/run_checks.gd`.
