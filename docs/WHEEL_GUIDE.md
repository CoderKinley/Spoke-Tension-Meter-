# Illustrated Wheel Guide

Open **Guide** in the bottom navigation, the help icon, or **tools → Wheel guide**.
The page works offline and pauses microphone capture. Its four topics share the
existing graphite/blue theme and use original Flutter vector illustrations.

## Topics and assumptions

- **Start here:** inspect axle seating and hub play, observe the rim independently
  of the tire, and check the bead line before treating a tire hop as a rim error.
  Includes the app's frequency-capture workflow and tire-service limits.
- **Nipple turns:** switch tightening/loosening and tire-bed/hub viewpoints. For
  ordinary right-hand-thread nipples mounted at the rim, clockwise tightens when
  looking from the tire bed toward the hub; the hub-side view reverses this.
  An arrow indicates direction only, never a prescribed amount of adjustment.
- **Side wobble:** choose a left/right rim deviation. The highlighted flange
  illustrates the corrective spoke pull. Spoke identity follows its hub flange,
  not the apparent position of a crossing.
- **Roundness:** switch high/low radial spots. The diagram distinguishes the
  actual contour from a reference circle and shows inward/outward correction.
  Changes across both flanges require checking lateral alignment, dish, and
  tension; the guide does not prescribe equal tensions on both sides.

The diagrams deliberately exaggerate errors. They are teaching diagrams, not a
scan of the user's wheel. No pitch, saved map, ideal-string estimate, or bike
preset generates adjustment commands. Damaged rims, tires, or seized parts need
assessment rather than more spoke adjustment. Manufacturer requirements govern
unusual nipple systems, tire fitting, and allowable tension/pressure.

## Research

Reviewed October 2026. Sources are also selectable/copyable within the page:

- [Park Tool: how wheel truing works](https://www.parktool.com/en-us/blog/repair-help/how-wheel-truing-works)
  explains the rim, spokes, lateral/radial alignment, dish, and tension.
- [Park Tool: lateral and radial truing](https://www.parktool.com/en-us/blog/repair-help/wheel-and-rim-truing)
  supports viewpoint-dependent turning, high/low radial definitions, and the
  interaction between adjustments.
- [Park Tool SW-2 instructions](https://www.parktool.com/assets/doc/product/SW-2_instructions.pdf)
  support the relationship between lateral deviation and flange selection.
- [Schwalbe: tire fitting](https://www.schwalbe.com/en/technology-faq/mounting/)
  supports bead-line inspection. The lower tire/rim pressure limit also follows
  [Schwalbe's tubeless guidance](https://www.schwalbe.com/en/technology-faq/tubeless/).

## Verification

Widget tests cover all four combinations of turning action/viewpoint, both
lateral directions, high/low radial guidance, diagram accessibility descriptions,
source expansion, compact screens at 200% text, landscape, and all three entry
points. Opening Guide stops capture and preserves the selected wheel and saved
readings. Guide rendering does not validate a real wheel repair.

Previews: [inspection](previews/guide.png), [turning](previews/guide-turns.png),
[lateral](previews/guide-lateral.png), [radial](previews/guide-radial.png).
