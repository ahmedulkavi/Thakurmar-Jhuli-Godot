# The Prince's Forest — Thakurmar Jhuli

A native Godot recreation of the game in `old-implementation/Side Scroll`: a short journey through a luminous forest. Guide the prince over a fallen log, mossy rocks, and banyan roots, claim a glowing sword, and fight forest shades on the way to the glowing tree.

## Play

Open **`project.godot` in Godot 4.7.2** and press **F6** with `scenes/main.tscn` open, or **F5** to run the project. No Node.js, browser, packages, or network connection is needed.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | A / D or Left / Right | Left stick or D-pad |
| Jump | Space | A / bottom face button |
| Attack / chain sword strikes after pickup | J / X / left mouse button | X / left face button |
| Pause / resume | Esc or the on-screen Pause button | Start |
| Restart, including while paused or finished | R | Y / top face button |
| Toggle fullscreen | F11 | — |

The game starts maximized to fit the current monitor. **F11** switches to the monitor's native fullscreen resolution, including **2560 × 1440 on a QHD / 2K display**, and restores the previous window mode when pressed again. Resizing updates the interface and the forest's rendering resolution automatically. The forest renders at its displayed pixel size while keeping the same gameplay view and proportions.

Hold jump for a higher leap; release it for a short hop. The controller includes a 100 ms grace period after leaving an edge and a 120 ms jump input buffer before landing. The pause and ending screens also work with mouse or keyboard focus (Enter / Space).

The rocks are a solid obstacle to jump over. Landing on them makes the prince slide back to the ground; they cannot be used as a platform or a jumping surface.

Jump onto the raised, anvil-shaped root to automatically collect the glowing Forest Blade. Attacks use painted full-body poses with an overhead slash, a lunging thrust, and a return to sword guard. Press the same attack button again to alternate slash and thrust; a brief gap returns to the opening slash. A press near the end of recovery queues the next attack, while holding the button performs only one attack. Bent knees, shoulder turns, and the trailing sash carry the movement through eight poses per attack.

The prince takes a small physical step into grounded strikes and keeps normal movement in the air. The sword can damage each shade once per attack, only during the cutting or extended thrust frames, and cannot pass through solid obstacles. Hits add a brief impact hold, sparks, and a blade trail. Taking damage interrupts an attack and cancels a queued follow-up. Two shades guard the final stretch. Their orange glow warns of an approaching lunge; strike to interrupt them or jump clear. Three sword hits defeat a shade.

After pickup, movement uses eight running poses with a natural forward-and-back sword-arm swing: the gripping hand travels behind the hip, passes beside the thigh, and swings forward as the opposite arm counter-swings. The short sword follows the hand and wrist through that arc. The running cycle follows distance travelled; registered hips and soles keep the body aligned when changing direction or entering combat. Jump, landing, and recoil use their own armed poses.

The health bar starts at 100. A shade's lunge deals 20 damage, knocks the prince back, and grants one second of protection with a flashing sprite. At zero health, use **Try Again** or **R** to restart. Restart restores health, enemies, and the sword pickup. Pause freezes combat along with movement.

Shades use painted walking, attack, jump, landing, recoil, and collapse poses. They notice the prince through line of sight, remember him for four seconds after losing sight, and pursue until he escapes their range or stays hidden. While chasing, they crouch and jump over the log, rocks, and raised root. Terrain probes prevent jumps into tall walls or low ceilings, and enemies return to their starting positions after pursuit ends. Attacks have a committed direction and a recovery period; sword hits interrupt them. Defeat removes the hitbox immediately, then plays a short collapse and fade.

## Project layout

- `scenes/main.tscn` — adaptive window and interface, game viewport with 1280 × 720 logical coordinates and native display rendering, and vignette.
- `scenes/forest.tscn` — editable 3840-pixel level, parallax layers, physical obstacles, particles, goal area, and camera.
- `scenes/prince.tscn` — `CharacterBody2D`, 44 × 122 collision shape, shadow, and `AnimatedSprite2D`.
- `scenes/prince_frames.tres` — the original 14 sprite frames mapped to idle, run, rise, fall, and landing animations.
- `scripts/player.gd` — exported movement settings and jump behavior.
- `scripts/prince_combat_visual.gd` — armed running (`assets/prince-armed-run-v2.png`), jump/landing/recoil (`assets/prince-armed-locomotion.png`), and slash/thrust poses (`assets/prince-combat-sheet.png`), plus blade trails and impact sparks.
- `scripts/sword_visual.gd` and `scripts/sword_pickup.gd` — glowing sword pickup and automatic collection on the raised root.
- `scripts/forest_enemy.gd` — shade awareness, pursuit, obstacle jumps, committed lunges, damage, and defeat.
- `scripts/forest_enemy_visual.gd` — registered enemy movement and action poses using `assets/forest-shade-animations.png`.
- `scripts/forest.gd` — journey reset, camera tracking, goal detection, and mist tweens.
- `scripts/main.gd` — native Godot interface, input, pause, and completion flow.
- `assets/` — copies of the original artwork, source sheets, and art provenance. All runtime assets are here.
- `tests/gameplay_test.gd` — automated gameplay integration checks.
- `tests/combat_test.gd` — pickup, keyboard/mouse/controller attacks, hit direction and reach, damage protection, defeat, and reset checks.
- `tests/combat_animation_test.gd` — windup and strike timing, alternating attacks, input buffering, pose mirroring, interrupts, and airborne combat checks.
- `tests/resolution_test.gd` — adaptive rendering from 816 × 564 to QHD, aspect ratios, paused resizing, mouse coordinates, and native fullscreen checks.
- `tests/enemy_ai_test.gd` — jumps over every obstacle in both directions, sight and pursuit memory, clearance checks, interrupts, defeat, pause, and reset.
- `old-implementation/` — original browser implementation, excluded from Godot scanning with `.gdignore`.

Godot handles character collisions, floor detection, animations, camera smoothing, three parallax layers, particle fireflies, UI focus, and pausing. Original artwork, level positions, and movement tuning are preserved, with sword combat added to the final stretch. The interface uses system serif and sans-serif fonts with fallbacks; proprietary font files are not bundled.

## Validation

With the Godot executable on your PATH:

```powershell
godot --headless --path . --script res://tests/gameplay_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/combat_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/combat_animation_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/resolution_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/enemy_ai_test.gd
```

The suite checks floor and boundary collisions, keyboard restart, running animation, the log collision, pause/resume, full and short jumps, buffered jumps, coyote time, traversal of all three obstacles, camera tracking, completion, and restarting from pause and completion. A failed check returns a nonzero exit code.

For a rendered run that also saves screenshots of the start, pause, journey, and ending to `artifacts/`:

```powershell
godot --path . --script res://tests/gameplay_test.gd -- --capture
godot --path . --script res://tests/combat_test.gd -- --capture
godot --path . --script res://tests/combat_animation_test.gd -- --capture
godot --path . --fixed-fps 60 --script res://tests/resolution_test.gd -- --capture
godot --path . --fixed-fps 60 --script res://tests/enemy_ai_test.gd -- --capture
```

Validated using Godot 4.7.2 with the Compatibility renderer. No external plugins are required.
