// EERI — THE GROUND'S COLOUR, PER WORLD, IN ONE PLACE THAT TOOLS CAN READ.
//
// These three tables lived inside `js/level.js` and were the browser build's
// alone. `godot/scenes/play.gd` — a hand-port of the same painter — carried
// its own retyped copies, and on 2026-09-07 they were measured against each
// other and had **already drifted**:
//
//     pipeworks lip   browser mix(GREEN, STEEL[2], 0.30)
//                     Godot   mix(GREEN, STEEL[2], 0.20)
//     nightshift lip  browser mix(mix(GREEN, INK, 0.48), SKY, 0.12)
//                     Godot   mix(GREEN, INK, 0.45)          ← no sky at all
//     grove earth     browser mix(E[1], GREEN_DK, 0.22) / mix(E[2], …, 0.38)
//                     Godot   mix(E[1], GREEN_DK, 0.12) / mix(E[2], …, 0.28)
//
// Nobody chose that. Somebody typed a number twice. It is precisely the
// failure CLAUDE.md's rule exists to stop — **content is authored once and
// flows; code is not shared** — and the reason scenery, levels, strings,
// glyphs and audio never drift is that each of them has an exporter and this
// did not.
//
// So the tables move here and `godot/tools/export-palette.mjs` reads them.
//
// WHY A NEW FILE RATHER THAN `js/palette.js`: nothing in here may import
// `three`. `js/level.js` does, on its first line, which is exactly why no
// exporter could ever read these tables where they were — Node cannot resolve
// a bare `three` specifier without the browser's import map. The same trap
// `js/artprops.js` documents from the other direction. Keeping them in a
// three-free module is what makes them exportable at all, and `palette.js` is
// the *palette* (the constants), while this is what the GROUND does with it.
//
// Every colour here is a `PAL` value mixed toward another `PAL` value. No new
// constants — if the art lane wants real per-world earth rather than a tint,
// these are the tables to replace, and both builds get it at once now.
import { PAL, mix } from './palette.js?v=61';

// ---- THE GROUND IS NOT THE SAME GROUND IN EVERY WORLD --------------------
//
// One `PAL.EARTH` ramp served all four worlds, so the strip you stand on was
// the identical brown under a sunlit construction site, a flooded trench, a
// forest and a night shift. It is the one band on screen in EVERY frame of
// the game — the backdrops change completely behind it and the floor
// underneath answered none of it, which is most of why four worlds read as
// the same place with different wallpaper.
//
// Each world TINTS the ramp rather than replacing it: the strata keep their
// order and their spacing, because the cut has to stay legible as a section.
//
//   groundworks  untouched. It is what everything else is judged against.
//   pipeworks    cooler and greyer — wet ground beside concrete.
//   grove        peat: darker, with humus in the topsoil, because the top of
//                a cut in a forest is roots and leaf litter.
//   nightshift   the whole ramp toward INK. Not "the same earth, darker" — a
//                warm brown goes BLUE before it goes black at night, so the
//                mix is toward the ink the night sky already uses.
//
// v15.51: the mixes were roughly doubled, because at the strengths above
// all four worlds still screenshotted as the same brown — Lambert and the
// detail map between them flatten a 15% tint to nothing a phone can see.
// And the night ramp goes toward SKY as well as INK: the blue is what says
// "night" rather than "dim".
export const EARTH_FOR = {
  groundworks: (E) => [E[0], mix(E[1], E[0], 0.5), E[1], E[2]],
  pipeworks: (E) => [
    mix(E[0], PAL.STEEL[0], 0.4),
    mix(mix(E[1], E[0], 0.5), PAL.STEEL[0], 0.36),
    mix(E[1], PAL.STEEL[1], 0.32),
    mix(E[2], PAL.STEEL[2], 0.28),
  ],
  grove: (E) => [
    mix(E[0], PAL.INK, 0.32),
    mix(mix(E[1], E[0], 0.5), PAL.INK, 0.24),
    mix(E[1], PAL.GREEN_DK, 0.22),
    mix(E[2], PAL.GREEN_DK, 0.38),
  ],
  nightshift: (E) => [
    mix(mix(E[0], PAL.INK, 0.58), PAL.SKY, 0.14),
    mix(mix(mix(E[1], E[0], 0.5), PAL.INK, 0.5), PAL.SKY, 0.13),
    mix(mix(E[1], PAL.INK, 0.44), PAL.SKY, 0.12),
    mix(mix(E[2], PAL.INK, 0.38), PAL.SKY, 0.1),
  ],
};

// The grass lip goes with it: a daylight green strip is wrong at night and
// wrong in a trench, and it is the brightest thing on the floor — so it is
// the first thing that gives the reuse away.
export const LIP_FOR = {
  groundworks: (g) => g,
  pipeworks: (g) => mix(g, PAL.STEEL[2], 0.3),
  grove: (g) => mix(g, PAL.GREEN_DK, 0.45),
  nightshift: (g) => mix(mix(g, PAL.INK, 0.48), PAL.SKY, 0.12),
};

// …AND SO DOES THE FELT FRINGE ON TOP OF IT, which for four worlds it did
// not. The rule above was written for `LIP_FOR`, applied to the 0.14 lip bar
// — and then the fringe was added (v15.59, answering the owner's "grass is
// always the same art multiplied") drawn at `color: 0xffffff`, i.e. the
// photograph's own daylight green, untouched, in every world. In THE NIGHT
// SHIFT it was the brightest thing in a blue-black frame.
//
// THESE ARE LIGHTS, NOT COLOURS. `cutMat`'s colour multiplies the map, so the
// nap, the cut tufts and the split pins all survive; a flat recolour would
// throw away the photograph the fringe is there for.
//
// AND THEY ARE NOT DERIVED FROM `LIP_FOR`, which was the first attempt and is
// worth recording because it looked so obviously right. Taking the ratio
// `LIP_FOR[world](GREEN) / LIP_FOR.groundworks(GREEN)` gives one number per
// channel that moves the fringe exactly as far as the lip moved, with no
// second table to keep in step. **It turned the night shift's grass PINK.**
// A hue ratio between two saturated greens is a huge red multiplier and a
// small green one, which is fine on the green pixels it was reasoned about
// and wrong on every neutral one — the pale card and balsa in the same
// photograph came out magenta. A light is desaturated by nature; a hue ratio
// is the opposite of one.
//
// `mix` works in the palette's own '#rrggbb' strings, so white is written the
// same way rather than as 0xffffff — passing a NUMBER here throws
// "a.slice is not a function" on the first frame, which is how this was found.
const WHITE = '#ffffff';
export const FRINGE_FOR = {
  // World 1 is the light the felt was photographed in. Unchanged, on purpose.
  groundworks: WHITE,
  // down among the pipes: cooler and a little paler, as the lip is
  pipeworks: mix(WHITE, PAL.STEEL[2], 0.22),
  // under the canopy: shaded, and the shade in a wood is green
  grove: mix(mix(WHITE, PAL.GREEN_DK, 0.22), PAL.INK, 0.12),
  // the night shift: dark, and blue because the only wide light is the sky
  nightshift: mix(mix(WHITE, PAL.SKY, 0.34), PAL.INK, 0.46),
};

/** The worlds these tables know about, in campaign order. */
export const GROUND_WORLDS = ['groundworks', 'pipeworks', 'grove', 'nightshift'];

/**
 * Every ground colour a world needs, RESOLVED to '#rrggbb'.
 *
 * This is the shape the exporter writes and the port reads, and it exists so
 * that the port never evaluates a mix: a mix is code, and code is the thing
 * that is not shared. Hand it a world it has never heard of and it answers
 * with `groundworks`, the same fallback `Level`'s constructor already makes.
 */
export function groundPalette(world) {
  const w = EARTH_FOR[world] ? world : 'groundworks';
  return {
    // deepest band first, topsoil last — the order `strata()` indexes by
    earth: EARTH_FOR[w](PAL.EARTH),
    lip: LIP_FOR[w](PAL.GREEN),
    fringe: FRINGE_FOR[w],
  };
}
