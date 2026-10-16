# Instrument Theme

The October 2026 palette update keeps the existing screen layouts, typography,
navigation, wheel mapping, and measurement behavior. Colors are centralized in
`lib/app/theme.dart`; custom painters use the same accent as Material controls.

## Research and design decision

- [Material 3 color roles](https://m3.material.io/styles/color/roles) distinguish
  surfaces, actions, and contrasting accents. The app uses neutral graphite
  surfaces, blue for primary actions and readings, and amber for the selected
  spoke and existing caution messages.
- [W3C text contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
  specifies 4.5:1 for normal text and 3:1 for large text. The palette targets the
  stricter threshold for the checked core text/surface pairs.
- [W3C use-of-color guidance](https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html)
  calls for cues beyond color. Existing text statuses, spoke numbers, filled
  recorded markers, outlined empty markers, and the enlarged selected marker
  remain in place.
- [Park Tool's Wheel Tension App](https://www.parktool.com/en-us/wta) provides
  relevant workshop context for spoke measurements. This app's graphite/blue
  appearance is our design interpretation, not a manufacturer recommendation,
  affiliation, or evidence of measurement accuracy.

Blue replaces the previous mint accent to give the interface an instrument-like
appearance without a green safety implication. A blue saved marker means a
reading exists; SETTLED still describes repeatability only.

## Palette

| Role | Color |
| --- | --- |
| Background | `#111419` |
| Cards | `#1C222B` |
| Frequency gradient start | `#243249` |
| Readings and actions | `#83B4FF` |
| Selected spoke and cautions | `#F2BD70` |
| Main text | `#EEF2F7` |
| Supporting text | `#ABB6C5` |

## Verification

The 16 checked opaque combinations of main text, supporting text, blue, and
amber against the four principal surfaces range from 4.76:1 to 16.42:1. This
checks palette pairs, not complete accessibility conformance or outdoor
readability. Existing unit/widget tests pass (65), including compact screens,
large text, landscape, and wheel-map interactions. Updated previews under
`docs/previews/` render actual Flutter widgets with synthetic readings; they
are not phone captures or physical accuracy validation.
