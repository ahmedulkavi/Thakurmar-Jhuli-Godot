# The Prince's Forest — Thakurmar Jhuli

A native Godot recreation of the game in `old-implementation/Side Scroll`: a short, peaceful journey through a luminous forest. Guide the prince over a fallen log, mossy rocks, and banyan roots to the glowing tree.

## Play

Open **`project.godot` in Godot 4.7.2** and press **F6** with `scenes/main.tscn` open, or **F5** to run the project. No Node.js, browser, packages, or network connection is needed.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | A / D or Left / Right | Left stick or D-pad |
| Jump | Space | A / bottom face button |
| Pause / resume | Esc or the on-screen Pause button | Start |
| Restart, including while paused or finished | R | Y / top face button |
| Toggle fullscreen | F11 | — |

Hold jump for a higher leap; release it for a short hop. The controller includes a 100 ms grace period after leaving an edge and a 120 ms jump input buffer before landing. The pause and ending screens also work with mouse or keyboard focus (Enter / Space).

The rocks are a solid obstacle to jump over. Landing on them makes the prince slide back to the ground; they cannot be used as a platform or a jumping surface.

## Project layout

- `scenes/main.tscn` — main window, 1280 × 720 game viewport, and vignette.
- `scenes/forest.tscn` — editable 3840-pixel level, parallax layers, physical obstacles, particles, goal area, and camera.
- `scenes/prince.tscn` — `CharacterBody2D`, 44 × 122 collision shape, shadow, and `AnimatedSprite2D`.
- `scenes/prince_frames.tres` — the original 14 sprite frames mapped to idle, run, rise, fall, and landing animations.
- `scripts/player.gd` — exported movement settings and jump behavior.
- `scripts/forest.gd` — journey reset, camera tracking, goal detection, and mist tweens.
- `scripts/main.gd` — native Godot interface, input, pause, and completion flow.
- `assets/` — copies of the original artwork, source sheets, and art provenance. All runtime assets are here.
- `tests/gameplay_test.gd` — automated gameplay integration checks.
- `old-implementation/` — original browser implementation, excluded from Godot scanning with `.gdignore`.

Godot handles character collisions, floor detection, animations, camera smoothing, three parallax layers, particle fireflies, UI focus, and pausing. Artwork, level positions, movement tuning, and the relaxed objective follow the original. The interface uses system serif and sans-serif fonts with fallbacks; proprietary font files are not bundled.

## Validation

With the Godot executable on your PATH:

```powershell
godot --headless --path . --script res://tests/gameplay_test.gd
```

The suite checks floor and boundary collisions, keyboard restart, running animation, the log collision, pause/resume, full and short jumps, buffered jumps, coyote time, traversal of all three obstacles, camera tracking, completion, and restarting from pause and completion. A failed check returns a nonzero exit code.

For a rendered run that also saves screenshots of the start, pause, journey, and ending to `artifacts/`:

```powershell
godot --path . --script res://tests/gameplay_test.gd -- --capture
```

Validated using Godot 4.7.2 with the Compatibility renderer. No external plugins are required.
