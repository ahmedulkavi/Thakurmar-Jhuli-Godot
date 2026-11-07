# Generated art prompts

Generated using the built-in image-generation tool. Source assets, runtime images, and final prompts are stored in this project. Transparent assets preserve their alpha; sprite sheets are sliced or framed with Godot atlas regions for use in the game.

## Armed locomotion — `prince-armed-locomotion.png`

This earlier sheet supplies jump, landing, and recoil poses. Its initial eight running poses were superseded by the arm-swing sheet below.

## Active armed run — `prince-armed-run-v2.png`

Generated and then refined with the built-in `image_gen` tool, using transparent backgrounds. The initial source is preserved at `source/prince-armed-run-v2-source.png`. The final 1774 × 887 image is an eight-frame 4 × 2 atlas. The sword arm swings backward and forward with the stride; the opposite arm counter-swings. Runtime scaling registers a 383-pixel source body to the same 122-pixel game height as the other prince sprites, with hips and soles aligned in both facing directions.

Generation prompt:

Use case: stylized-concept.
Asset type: transparent 2D game RUN CYCLE, exactly EIGHT full-body animation frames in a uniform FOUR-COLUMN by TWO-ROW grid of square cells, widescreen 2:1 sheet. One full-body prince per cell. Read left to right then next row.
Reference 1: original prince sprite strip, for identity, costume, hand-painted style and ordinary human running mechanics. Reference 2: combat sheet, for the same character and exact SHORT SWORD design only; do not copy the combat guard poses.
Character: same lean young Indian prince, warm brown skin, swept dark hair, small gold crown, cream dhoti, diagonal cream shoulder wrap, gold belt and bracelets, orange saffron sash trailing behind, bare feet. Entire body faces RIGHT in side profile throughout, slight forward running lean, same size and light in every cell.
PRIMARY REQUIREMENT: natural human RUNNING with a short sword in the near/right hand. The weapon arm must PUMP FORWARD AND BACK FROM THE SHOULDER through a LARGE visible arc, elbow naturally flexing. The hand moves from BEHIND THE HIP at the backward extreme to IN FRONT OF THE LOWER CHEST at the forward extreme. It passes beside the thigh during the middle positions. The opposite empty arm counter-swings, opposite the sword arm. Torso twists subtly with opposing shoulders and hips. Sword is gripped firmly and FOLLOWS THE HAND AND WRIST through the entire arc, tipping backward/down when behind the hip, hanging diagonally down near the thigh, then pointing upward/forward with the forward arm swing. This is ordinary running with an object in hand, not a combat stance. Do NOT keep the sword hand fixed at the waist. Do NOT repeat the same upper-body pose in all frames. Back-swing frames MUST visibly show the sword hand behind the torso. Front-swing frames MUST visibly show the sword hand ahead of the torso.
SWORD INVARIANT: exactly one straight short silver-teal blade, modest gold crossguard, short dark handle, same as reference 2. Grip-to-tip length exactly 39% of the character's fully standing height, constant across all eight frames; only orientation changes. Blade and hand are part of each painted sprite, firmly connected. No motion trails or broad magical halos.
Precise consecutive gait poses:
TOP ROW frame 1: right foot makes forward contact, left leg trails; RIGHT/SWORD UPPER ARM pulled BEHIND the torso, sword fist behind right hip, blade directed backward and down; empty left fist forward near chest.
TOP ROW frame 2: right leg takes weight, left knee starts coming through; sword arm begins its forward swing from BEHIND hip, sword still low and backward; empty arm begins receding.
TOP ROW frame 3: left leg passes forward, right leg beneath body; sword hand swings past the OUTSIDE OF THE THIGH toward waist level, blade diagonally down-forward; empty hand passes back beside the torso.
TOP ROW frame 4: airborne transition toward left foot contact, left knee forward, right leg behind; sword arm swings clearly FORWARD with bent elbow, fist ahead of lower chest, blade tilted UP and forward; empty arm behind hip.
BOTTOM ROW frame 5: left foot makes forward contact, right leg trails; sword hand at FORWARD swing extreme, bent elbow, fist well in front of lower chest, blade diagonal UP and forward; empty arm far back.
BOTTOM ROW frame 6: left leg takes weight, right knee starts advancing; sword arm swings DOWN from front toward hip, blade diagonal forward-down; empty arm returns forward.
BOTTOM ROW frame 7: right leg passes forward, left leg beneath body; sword hand passes DOWN beside the OUTSIDE OF THE THIGH moving BACKWARD, blade tipped down and backward; empty hand ahead of waist.
BOTTOM ROW frame 8: airborne transition toward right foot contact; sword arm reaches clearly BEHIND hip again, blade diagonal backward/down, empty arm ahead of chest. Flows into frame 1 without a pause.
Registration: same anatomy, head size, sword length and hip-centered camera in all cells. Feet on a common invisible ground baseline at 90% of cell height in contact frames; natural compression and airborne phases. Fully upright crown near 14% of cell height. Leave enough transparent margin BEHIND AND BELOW the body to fit backward-swing swords, and in front for the forward swing. Each complete blade, sash, limb and head must remain INSIDE its own cell with clear transparent separation. Genuinely transparent alpha, no floor, no shadows, no background, no grid lines, no numbers, no captions, no watermark. Painterly game animation, not vector or 3D.

Final refinement prompt:

Use case: precise-object-edit and background-extraction.
Edit the supplied EIGHT-frame 4-column by 2-row hand-painted prince run-cycle sprite sheet. Keep its exact canvas dimensions, grid, frame positions, character identity, body scale, every arm pose, natural shoulder/elbow swing, leg poses and sash poses unchanged. Preserve the sword-hand grip and weapon direction in each cell. These natural rear-hand, passing-hand and forward-hand poses are essential; do not replace them with a fixed guard stance.
Make ONLY these two changes:
1. Remove ALL faint beige/gray/white colored background haze and edge halos between and around the characters. Outside the actual sprites must be genuinely empty transparent alpha, alpha zero, not a colored matte or translucent mist. Preserve clean anti-aliased edges on the actual painted characters and swords. No ground, background or shadows.
2. Make every sword the same short-sword size as the game's combat poses: grip-to-tip blade length exactly 39% of the prince's fully standing crown-to-sole height. The current blades are slightly too short. Extend the blade along its EXISTING direction by about 25%, preserving the small gold crossguard, dark grip, existing gripping hand and blade width. All eight blades must have the SAME physical length even when pointed backward/down, alongside the thigh, or forward/up. Keep tips fully within their respective grid cells. Do not change hands, do not add another blade, do not add glow or motion trails.
Preserve everything else, including the full forward-and-back sword-arm swing and the layout of all eight frames. Output a clean transparent PNG sprite sheet.

## Original armed locomotion prompt

Generated using the built-in `image_gen` tool with `transparent_background: true`, the combat sheet as the character/sword reference, and the original locomotion strip as the gait reference. The 1254 × 1254 RGBA source is preserved. Rows 1–2 contain the eight running frames, row 3 contains rise/apex/fall poses, and row 4 contains landing/recoil poses. The sword is part of each full-body sprite. Runtime rendering uses the same 0.44 scale as the combat sprites, registered foot baselines, and a distance-driven stride cycle.

Final prompt:

Use case: stylized-concept.
Asset type: transparent production 2D ARMED LOCOMOTION sprite sheet, exactly 4 equal columns by 4 equal rows, 16 cells total, square canvas.
Reference image 1 is the existing COMBAT SHEET and defines the exact prince identity, painterly style, clothing and short sword design. Reference image 2 shows the original unarmed running and jumping poses, for gait reference only. Create a new armed locomotion sheet, do not reproduce either reference's layout.
Preserve the same young Indian prince: warm brown skin, lean athletic build, dark swept hair, small gold crown, cream dhoti and diagonal cream shoulder wrap, trailing orange/saffron sash, gold belt and bracelets, bare feet. Side profile facing RIGHT in EVERY cell, same anatomy, scale, light and painting style as combat reference.
CRITICAL SWORD CONSISTENCY: exactly ONE short straight silver-teal blade with the same small gold crossguard and dark short handle as reference 1, integrated into his forward/right GRIPPING HAND in EVERY frame. Grip-to-tip length must remain exactly 39% of his fully standing crown-to-sole height, about the length of his forearm plus one hand. This is a SHORT sword, never a large broadsword. Same blade length, blade width, hilt and crossguard in all 16 frames, no perspective foreshortening. The blade points forward-right about 20 degrees above horizontal, held at waist/lower-rib height, with the sword elbow bent, in a controlled carrying position. Subtle arm motion is fine; never sweep it overhead, swing it behind the body or through his legs. Opposite/free arm moves naturally for balance. No separate floating sword and no empty gripping hand. Do not add blade trails or wide glow halos.
Read frames left-to-right, then top-to-bottom:
Row 1 = first half of one smooth looping run cycle: (1) right foot forward contact, left leg stretched back; (2) right leg weight-bearing compression, left knee swings through; (3) passing pose right leg beneath hip, left knee advancing; (4) flight/up pose left knee high, right foot trailing.
Row 2 = second half of run cycle: (5) left foot forward contact, right leg stretched back; (6) left leg weight-bearing compression, right knee swings through; (7) passing pose left leg beneath hip, right knee advancing; (8) flight/up pose right knee high, left foot trailing. Keep sword firmly carried in front throughout this entire cycle, sash billows behind and follows through naturally.
Row 3 = airborne poses: (1) rising jump with one knee lifting; (2) near-apex jump, both knees tucked; (3) descending, lead foot reaches down; (4) descending with both feet preparing to land. All four retain the same short sword in the same forward/right hand in front of the body.
Row 4 = landing and recoil: (1) soft landing knees bent; (2) recovering toward upright sword guard; (3) struck/recoil, body leaning slightly back, bent knees, sword still in the gripping hand; (4) settling from recoil into low guard.
Registration: sixteen separate complete full-body sprites, exactly one per equally sized cell, centered at the hips, same body scale in EVERY cell. Contact and landing feet rest at 90% of cell height; airborne/run-flight feet may rise naturally above this shared ground baseline. Fully upright crown near 15% cell height. Leave generous transparent safety margins around sword tips, sash and every limb. No neighboring overlap, no clipped sword, no cut off feet. Genuinely transparent alpha background. No floor, shadows, scenery, cell borders, guides, numbering, labels, text, watermark or UI. Match the hand-painted combat artwork, not vector art, pixel art, or glossy 3D.

## Prince reference — `source/prince-reference.png`

Use case: stylized-concept. Create an original character reference for a side-scrolling fantasy game: a young Indian prince with warm brown skin, dark swept hair, a small gold crown, cream dhoti-inspired clothing, a flowing saffron sash and understated gold jewelry. Full body, side profile facing right, athletic readable silhouette, feet visible, no weapons. Hand-painted 2D animation concept art with dramatic dark shapes and soft luminous accents; mystical forest atmosphere, teal and warm gold. Plain unobtrusive background, no text, no logos.

## Prince sprites — `source/prince-sheet.png`

Use case: stylized-concept. Create a clean transparent sprite sheet for the SAME Indian prince in the reference, side view facing right, wearing a small gold crown, cream dhoti and flowing orange sash. Side-scrolling game animation. Precise uniform 4 columns by 4 rows grid, with exactly one complete full-body character per cell, each centered and clearly separated by transparent empty space, no overlap. Row 1: four subtle idle breathing poses. Row 2: four consecutive running poses. Row 3: two more running poses, then rising and falling jump poses. Row 4: two landing poses, then two empty cells. Keep character identity, height, scale, lighting and camera angle consistent in every cell; feet aligned on baseline within each cell. Painterly 2D game sprite, legible silhouette, no shadow, no floor, no border, no labels, no text.

## Distant forest — `forest-background.png`

Use case: stylized-concept. Asset type: wide side scrolling 2D game background. Create an original enchanted Indian forest vista, twilight, very wide horizontal composition. Painted parallax-game background: towering twisted banyan trunks and dense leaves in dark indigo and teal, distant misty turquoise forest, small patches of cyan and warm gold light. Dreamlike atmospheric layered depth with clear dark silhouettes and luminous painterly lighting, reminiscent of atmospheric hand-painted metroidvania games, no characters, no UI, no text, no watermark. The lower quarter is dark forest floor, with open midground suitable for placing a visible character.

## Middle forest — `forest-middle.png`

Use case: stylized-concept. Create a wide transparent middle-ground layer for a 2D side-scrolling forest platform game: several softly lit ancient banyan trunks, roots and dense fern silhouettes along the lower edge, with space between trees and empty transparent sky. Original painterly fantasy game art, desaturated indigo and teal, subtle turquoise highlights, side view, no people, no text, no solid background.

## Foreground foliage — `forest-foreground.png`

Use case: stylized-concept. Transparent PNG overlay for a 2D side scrolling game, foreground forest foliage only: silhouettes of banyan branches, long hanging vines and leaves descending from the top and framing left and right edges, some small cyan bioluminescent leaves, open transparent center and transparent bottom. Wide landscape composition. Hand-painted dark indigo and teal mystical forest illustration, soft luminous details, no background, no text, no people, no ground.

## Obstacles and tree — `source/forest-objects.png`

Use case: stylized-concept. Asset type: transparent foreground sprite sheet for an original 2D forest platform game. Four separate large objects laid out across a horizontal canvas with generous transparent gaps, all resting on same invisible baseline: a horizontal low fallen mossy log, a cluster of low mossy rocks, a low raised gnarled banyan root platform, and a tall magical banyan tree glowing softly in warm gold and cyan. Hand-painted game art, dark teal and indigo shadows, luminous cyan moss, atmospheric detail, clean silhouette, side view, no background, no text, no border, no characters.

## Ground — `source/ground.png`

Use case: stylized-concept. 2D side scrolling platform game ground tile. A horizontal long seamless continuous strip of dark ancient forest earth, moss and roots, viewed from the side, flat top surface, painted indigo teal with soft green moss highlights. Straight level top edge, deep soil filling lower half, edge can repeat. Isolated on transparency above surface, no objects, no text.

## Forest shade — `forest-shade.png`

Generated with the built-in `image_gen` tool with `transparent_background: true`. The original alpha is preserved. Godot frames the painted silhouette at 78 pixels tall using a sprite region that excludes faint alpha haze at the canvas edges. Mipmaps keep the small sprite smooth; breathing, facing, warning tint, and damage flashes are animated in code.

Final prompt:

Use case: stylized-concept.
Asset type: single transparent PNG enemy sprite for an existing hand-painted side-scrolling Bengali fairy-tale forest platform game.
Primary request: one small ominous forest shade, a squat enchanted creature made of twisted banyan roots, layered dark moss, and wisps of teal smoke. Two pale mint luminous eyes peer out from a shadowy hollow face, short branching wooden horns, ragged root feet, stubby clawed branch arms. Readable threatening but not gory. This shade will be displayed only 65 pixels tall next to a 122-pixel-tall Indian prince.
Style/medium: detailed hand-painted 2D game sprite with brushy organic contours and dimensional bark shading; rich indigo and deep teal shadows, desaturated moss green, restrained cyan rim light, a few warm earthy bark highlights. Match a luminous atmospheric painted fantasy forest with banyan trees and turquoise moss. Avoid flat vector art, cute emoji, glossy 3D, and pixel art.
Composition/framing: exactly one complete creature, isolated, neutral idle stance, body in a slight three-quarter side view facing LEFT, full body including root feet, compact roughly 4:5 width-to-height silhouette, centered with 10% clear padding on every side. All limbs visible and uncropped. Eyes and claw silhouette readable at very small scale. Feet share a level invisible ground baseline.
Scene/backdrop: genuinely transparent alpha background, no floor, no cast shadow, no scenery, no frame, no labels, no text, no watermark. Keep outer glow tight, no large diffuse background halo. One sprite only, no sheet, no variants.

## Prince combat poses — `prince-combat-sheet.png`

Generated with the built-in `image_gen` tool, `transparent_background: true`, and `source/prince-reference.png` as the character design reference. The original 1254 × 1254 RGBA sheet is preserved. The 4 × 4 atlas contains eight slash poses followed by eight thrust poses, including sword guard. Runtime atlas regions use the shared foot baseline; mipmaps and a small alpha cutoff remove faint generation haze when rendering. The original locomotion artwork remains separate.

Final prompt:

Use case: stylized-concept.
Asset type: production transparent full-body 2D combat sprite sheet, exactly 4 columns by 4 rows, 16 equally sized square cells, ideally 2048x2048 canvas.
Reference image 1 is the EXISTING character design reference. Preserve the SAME young Indian prince: warm brown skin, dark swept hair, small gold crown, cream dhoti and cream diagonal shoulder cloth, orange/saffron trailing sash, gold belt and bracelets, bare feet. Match his lean anatomy and hand-painted animated game art. Do not reproduce the reference's collage layout or background.
Primary request: sixteen distinct sequential combat poses of this prince wielding one short straight pale silver-teal glowing sword with gold crossguard, firmly gripped in his forward/right hand. The sword is about 55% of his standing height. All characters face RIGHT in side profile throughout, same scale and lighting. Natural trained sword technique: weight shifts through hips, bent knees and elbows, opposing shoulder rotation, back hand balances, orange sash lags behind the action. Include the sword and correct gripping hand in every frame. Never a sword hovering beside an idle person.
Layout and sequence, read left-to-right, then top-to-bottom:
Row 1 = slash frames 1-4: (1) relaxed bent-knee sword guard at waist; (2) weight on rear foot, draw sword hand back and UP behind head for windup; (3) elbow leads forceful overhead diagonal slash, blade pointing up and forward; (4) blade cuts down forward across chest, torso twisting, lead knee bends.
Row 2 = slash frames 5-8: (5) slash follow-through low forward, sword diagonally down in front, weight over forward foot; (6) settle into low follow-through, sash still trailing; (7) retract hand and raise blade returning to guard; (8) relaxed guard matching frame 1.
Row 3 = thrust frames 1-4: (1) same relaxed sword guard; (2) coil torso and pull sword hand beside rear hip, sword levels horizontally right; (3) begin thrust, elbow extends and front foot steps; (4) full forward lunge, bent front knee, straight rear leg, sword and extended hand pointing horizontally RIGHT at enemy waist height.
Row 4 = thrust frames 5-8: (5) full extension one more instant, shoulder and hip forward; (6) withdraw blade with elbow bending and weight receding; (7) step back and raise guard; (8) relaxed guard matching first pose.
Registration is critical: each cell has the SAME prince standing height, hips near the horizontal CENTER of the cell, and soles touching one consistent baseline at 88% of cell height. Standing crown height at 25% of cell height. Knees and torso naturally lower in lunges. All weapons, heads, sash and limbs fit fully within EACH cell, with transparent empty gaps, no neighboring sprite overlap. One complete prince per cell only. No ground shadows, scenery, guides, grid lines, border, numbers, captions, text, UI, or watermark. Genuinely transparent alpha background. No painted sword trails or broad glow arcs; game code will add motion trails.
