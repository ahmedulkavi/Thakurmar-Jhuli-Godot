# The Prince’s Forest

A short, relaxed 2D browser game about a prince finding his way through a luminous forest.

## Play locally

Install Node.js 16 or newer, open a terminal in this folder, and run:

```sh
npm start
```

Open <http://127.0.0.1:3000/> in a desktop browser. The game, Phaser, and artwork are local; no installation or internet connection is needed to play. Press Ctrl+C in the terminal to stop the server.

Move with **A/D** or **Left/Right**, jump with **Space**, pause with **Esc**, and restart with **R**. Hold jump longer for a higher jump. Reach the glowing tree to finish.

## Development

`src/config.js` contains movement tuning, level geometry, and animation frame mappings. `src/game.js` handles the scene and controls. Run `npm run check` for JavaScript syntax checks. For the optional automated Chrome smoke test, run `npm install`, start the game in another terminal, then run `npm run test:browser`; the test expects Chrome at its usual Windows installation path and uses the `playwright-core` development dependency.

Generated images are in `assets/`, source sheets and reference art in `assets/source/`, and generation prompts in `assets/ART-PROMPTS.md`. `scripts/prepare-art.py` slices and aligns the source sheets; running it requires Python and Pillow, but playing the game does not. The bundled Phaser license is in `vendor/PHASER-LICENSE.md`.
