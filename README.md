# The Prince's Forest — Thakurmar Jhuli

A native Godot recreation of the game in `old-implementation/Side Scroll`: a journey through a luminous forest. Claim the glowing sword near the start, jump between branches, and fight forest shades and flying bats on the way to the glowing tree.

## Play

Open **`project.godot` in Godot 4.7.2** and press **F6** with `scenes/main.tscn` open, or **F5** to run the project. No Node.js, browser, packages, or network connection is needed.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | A / D | Left stick |
| Select Royal / Steel stance | Left / Right arrow | D-pad left / right |
| Jump | Space | A / bottom face button |
| Climb revealed ladder | W / Up; S / Down | D-pad up / down or left stick |
| Attack / chain sword strikes after pickup | J / X / left mouse button | X / left face button |
| Focus healing after amulet pickup | Hold H | B / right face button |
| Rest at the fountain | E | Right shoulder / RB |
| Open merchant while resting | W / Up | D-pad up |
| Toggle god mode (debug) | G | Select / Back |
| Pause / resume | Esc or the on-screen Pause button | Start |
| Restart, including while paused or finished | R | Y / top face button |
| Toggle fullscreen | F11 | — |

The game starts maximized to fit the current monitor. **F11** switches to the monitor's native fullscreen resolution, including **2560 × 1440 on a QHD / 2K display**, and restores the previous window mode when pressed again. Resizing updates the interface and the forest's rendering resolution automatically. The forest renders at its displayed pixel size while keeping the same gameplay view and proportions.

Hold jump for a higher leap; release it for a short hop. The controller includes a 100 ms grace period after leaving an edge and a 120 ms jump input buffer before landing. The pause and ending screens also work with mouse or keyboard focus (Enter / Space).

The rocks are a solid obstacle to jump over. Landing on them makes the prince slide back to the ground; they cannot be used as a platform or a jumping surface.

Jump onto the raised, anvil-shaped root near the start to automatically collect the glowing Forest Blade. Collection pauses the journey for an animated item reveal with the blade, a light ring, sparks, its name, and a short description before control returns automatically. Attacks use painted full-body poses with an overhead slash, a lunging thrust, and a return to sword guard. Press the same attack button again to alternate slash and thrust; a brief gap returns to the opening slash. A press near the end of recovery queues the next attack, while holding the button performs only one attack. Bent knees, shoulder turns, and the trailing sash carry the movement through eight poses per attack.

Beyond the rocks, five rooted branch platforms form a staircase up and back down. Jump through a branch from below to land on top, and hold jump to reach the next branch. The ground path remains open in front of the trunks.

Defeat the three blue-glowing bats to make a single ladder appear in a smoky magic poof. Its foot rests on the highest central branch, and it leads to a broad raised deck. Move across the deck and jump to the surrounding upper branches. Hold **W / Up** to climb or **S / Down** to descend. The prince steps off automatically at either end; jump to leave the ladder early. Climbing uses separate upward and downward sprite animations.

From the rightmost upper branch, make a running jump to the floating island and collect the Healing Amulet. Its animated unlock presentation introduces the blue magic bar beneath stamina. The bar starts empty and each confirmed sword hit grants **20 magic**; missed and blocked attacks grant none. Hold **H** with at least **40 magic** while standing to focus for **0.9 seconds**, spend the magic, and restore **30 health**. The prince cannot move during focus. Releasing early or taking damage cancels healing without spending magic.

The prince takes a small physical step into grounded strikes and keeps normal movement in the air. The sword can damage each shade once per attack, only during the cutting or extended thrust frames, and cannot pass through solid obstacles. Hits add a brief impact hold, sparks, and a blade trail. Taking damage interrupts an attack and cancels a queued follow-up. Six shades guard the forest, including four beyond the old clearing. Their orange glow warns of an approaching lunge; strike to interrupt them or jump clear. Four sword hits defeat a shade. Their windup lasts 0.24 seconds, followed by a faster lunge and 0.60 seconds of recovery.

After pickup, movement uses eight running poses with a natural forward-and-back sword-arm swing: the gripping hand travels behind the hip, passes beside the thigh, and swings forward as the opposite arm counter-swings. The short sword follows the hand and wrist through that arc. The running cycle follows distance travelled; registered hips and soles keep the body aligned when changing direction or entering combat. Jump, landing, and recoil use their own armed poses.

The health bar starts at 100. A shade's lunge deals 25 damage, knocks the prince back, and grants one second of protection with a flashing sprite. At zero health, use **Try Again** or **R** to restart. Restart restores health, stamina, enemies, and the sword pickup. Pause freezes combat along with movement.

Defeated monsters drop spinning ghostly coins. Touch one to collect its **Essence**, shown in the upper-right counter: regular bats drop **10**, blue guardian bats **15**, and shades **25**. The first coin opens a skippable introduction. Collected Essence and its discovery survive fountain rests and checkpoint retries. Resting or retrying clears uncollected drops as enemies return; starting a new journey resets the total.

The green stamina bar below health starts at **100**. Each slash or thrust costs **15 stamina** when it begins, including attacks that miss or get interrupted. Seven rapid attacks exhaust the pool. Stamina recovers at **35 per second** after **0.5 seconds** without starting another attack. A strike with some stamina remaining but less than 15 still executes, empties the bar, and delays the next regeneration for **0.65 seconds**. At zero stamina, attacks are blocked, but further attack presses do not delay recovery. Queued follow-ups require some stamina, and holding a rejected attack does not trigger it later. Running and jumping do not consume stamina. Pause and defeat freeze recovery.

Shades use painted walking, attack, jump, landing, recoil, and collapse poses. They notice the prince through line of sight, remember him for four seconds after losing sight, and pursue until he escapes their range or stays hidden. While chasing, they crouch and jump over the log, rocks, and raised root. Terrain probes prevent jumps into tall walls or low ceilings, and enemies return to their starting positions after pursuit ends. Attacks have a committed direction and a recovery period; sword hits interrupt them. Defeat removes the hitbox immediately, then plays a short collapse and fade.

Three guardian bats patrol the original staircase; three more hunt among the branches farther into the forest. Before diving, the blue guardians show an orange warning ring, while the other bats glow orange; their dive deals 15 damage. Two sword hits defeat a bat, and a sword hit interrupts its attack. Bats return to their roosts after a dive and reset on restart. Beyond the former ending, two branch staircases and a final ascent provide raised routes above logs, roots, rocks, and the shades on the ground. Past the banyan tree, press **E** or **RB** at the old fountain to rest. Rest fully restores health and stamina, revives enemies, and activates a checkpoint while preserving collected items and magic. The prince remains seated until another key, button, click, or tap. After a defeat, **Try Again** returns him to the fountain; a normal restart begins the journey again.

Inspired by Bengali folklore descriptions of Shakchunni as a tree-dwelling spirit associated with conch-shell bangles ([USC folklore archive](https://folklore.usc.edu/bengali-legend-shakchunni/), [The Daily Star](https://online.thedailystar.net/life-living/news/top-6-bengali-supernatural-beings-you-should-know-about-halloween-3157066)).

Beyond the fountain, press **E / RB** at the fog to enter Shakchunni's arena. The fog seals during the fight and checkpoint retry resets her. She moves around the arena as she fights. Climb the floating islands to reach her upper body; evade the marked locations before her arm curls out and whips toward them. Her attack torso blends into the idle and laugh poses. After every few strikes she laughs and becomes invulnerable, then attacks much faster for a short time. Defeating her completes the journey.

The original looping track at `assets/forest-music.ogg` plays during the journey. Set `FOREST_MUSIC_ENABLED` in `scripts/main.gd` to disable it. Its source render can be recreated with `tools/compose_forest_music.py` (Python and NumPy), then encoded as Ogg Vorbis.

Crossing the fog starts `assets/shakchunni-music-louder.ogg`, an original boss loop with synthesized Indian instrument sounds. The original version is kept at `assets/shakchunni-music.ogg`. The forest track returns after the encounter or a retry. Its render script is `tools/compose_shakchunni_music.py`.

Short sound effects accompany landings, combat, healing, stance changes, and pickups. The effects in `assets/sfx/` can be regenerated with `tools/create_sound_effects.py` (Python and NumPy).

Steel remains selected after a checkpoint retry; a new journey returns to Royal. The stance icon appears below the resource bars.

For debugging, **G / Select** toggles god mode. The prince takes no damage, sword hits defeat enemies instantly, and Essence is unlimited. Purchases made in god mode do not spend the collected balance. The setting remains active across restarts until toggled off.

While resting at the old fountain, press **W / Up** to visit the merchant. Steel Stance costs **200 Essence** and can be purchased once per journey. The purchase survives checkpoint retries; a new journey clears it. Steel reduces incoming damage by 75%. Press attack shortly before an enemy hit to counter for heavy damage; ordinary attacks are unavailable in Steel. Use up / down to choose an option and controller A / X to select it. Leave the merchant to return to the resting pose.

## Project layout

- `scenes/main.tscn` — adaptive window and interface, game viewport with 1280 × 720 logical coordinates and native display rendering, and vignette.
- `scenes/forest.tscn` — forest level, parallax layers, physical obstacles, particles, and camera; the boss arena extends it at runtime.
- `scenes/prince.tscn` — `CharacterBody2D`, 44 × 122 collision shape, shadow, and `AnimatedSprite2D`.
- `scenes/prince_frames.tres` — the original 14 sprite frames mapped to idle, run, rise, fall, and landing animations.
- `scripts/player.gd` — movement, jumping, sword combat, health, stamina, magic generation, and focused healing.
- `scripts/prince_combat_visual.gd` — armed running (`assets/prince-armed-run-v2.png`), jump/landing/recoil (`assets/prince-armed-locomotion.png`), and slash/thrust poses (`assets/prince-combat-sheet.png`), plus blade trails and impact sparks.
- `scripts/sword_visual.gd` and `scripts/sword_pickup.gd` — glowing sword pickup and automatic collection on the raised root.
- `scripts/forest_enemy.gd` — shade awareness, pursuit, obstacle jumps, committed lunges, damage, and defeat.
- `scripts/forest_enemy_visual.gd` — registered enemy movement and action poses using `assets/forest-shade-animations.png`.
- `scripts/forest_bat.gd` and `shaders/bat_wings.gdshader` — flying bat patrols, telegraphed dives, combat, and wing animation.
- `scripts/forest_ladder.gd` and `scripts/prince_climb_visual.gd` — bat-gated ladder, climbing controls, and eight-frame climb sheet.
- `scripts/fountain_water.gd` and `scripts/distant_leaves.gd` — flowing fountain highlights, ripples, and drifting background leaves.
- `scripts/magic_amulet.gd` — animated amulet pickup on the floating upper island.
- `scripts/essence_drop.gd` — rotating, collectible Essence coins dropped by defeated enemies.
- `scripts/forest.gd` — journey reset, camera tracking, goal detection, and mist tweens.
- `scripts/main.gd` — native Godot interface, input, pause, and completion flow.
- `assets/` — copies of the original artwork, source sheets, and art provenance. All runtime assets are here.
- `tests/gameplay_test.gd` — automated gameplay integration checks.
- `tests/combat_test.gd` — pickup, keyboard/mouse/controller attacks, hit direction and reach, damage protection, defeat, and reset checks.
- `tests/combat_animation_test.gd` — windup and strike timing, alternating attacks, input buffering, pose mirroring, interrupts, and airborne combat checks.
- `tests/resolution_test.gd` — adaptive rendering from 816 × 564 to QHD, aspect ratios, paused resizing, mouse coordinates, and native fullscreen checks.
- `tests/enemy_ai_test.gd` — jumps over every obstacle in both directions, sight and pursuit memory, clearance checks, interrupts, defeat, pause, and reset.
- `tests/stamina_test.gd` — attack costs, exhaustion, delayed regeneration, combo buffering, free movement, pause, defeat, and reset behavior.
- `tests/forest_expansion_test.gd` — early sword pickup, the full branch staircase, bat attacks, sword hits, pause, and reset.
- `tests/extended_forest_test.gd` — the extended route, new staircase jumps, enemy reset, and relocated ending.
- `tests/fountain_rest_test.gd` — fountain interaction, recovery, enemy reset, sitting, and checkpoint retry.
- `tests/shakchunni_test.gd` ? fog gate, reachable islands, boss combat, phases, retry, and victory.
- `tests/merchant_test.gd` ? merchant access, affordability, purchase, and reset checks.
- `tests/essence_test.gd` — enemy drops, values, collection, HUD, pause, rest, and retry.
- `tests/ladder_test.gd` — bat-gated ladder reveal, climbing in both directions, upper platforms, pause, and reset.
- `tests/magic_amulet_test.gd` — floating-island jump, unlock presentation, magic from confirmed hits, healing, interruption, HUD, and reset.
- `old-implementation/` — original browser implementation, excluded from Godot scanning with `.gdignore`.

Godot handles character collisions, floor detection, animations, camera smoothing, three parallax layers, particle fireflies, UI focus, and pausing. The interface uses system serif and sans-serif fonts with fallbacks; proprietary font files are not bundled.

## Validation

With the Godot executable on your PATH:

```powershell
godot --headless --path . --script res://tests/gameplay_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/combat_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/combat_animation_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/resolution_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/enemy_ai_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/stamina_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/forest_expansion_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/extended_forest_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/fountain_rest_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/essence_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/ladder_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/magic_amulet_test.gd
```

The suite checks floor and boundary collisions, keyboard restart, running animation, the log collision, pause/resume, full and short jumps, buffered jumps, coyote time, traversal of all three obstacles, camera tracking, completion, and restarting from pause and completion. A failed check returns a nonzero exit code.

For a rendered run that also saves screenshots of the start, pause, journey, and ending to `artifacts/`:

```powershell
godot --path . --script res://tests/gameplay_test.gd -- --capture
godot --path . --script res://tests/combat_test.gd -- --capture
godot --path . --script res://tests/combat_animation_test.gd -- --capture
godot --path . --fixed-fps 60 --script res://tests/resolution_test.gd -- --capture
godot --path . --fixed-fps 60 --script res://tests/enemy_ai_test.gd -- --capture
godot --path . --fixed-fps 60 --script res://tests/stamina_test.gd -- --capture
godot --path . --fixed-fps 60 --script res://tests/forest_expansion_test.gd -- --capture
```

Validated using Godot 4.7.2 with the Compatibility renderer. No external plugins are required.
