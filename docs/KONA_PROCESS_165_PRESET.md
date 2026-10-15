# Kona Process 165 / Race Face AR35 preset

Researched 2026-10-15. This is an equipment preset for frequency logging, with no assigned target frequency or validated tension conversion.

## The user's build

The owner confirmed a **2019 Kona Process 165**, **27.5-inch Race Face AR35 replacement rims**, fitted approximately **2021**, and supplied **272 mm** as the vibrating length. The installation year is approximate; it does not establish the rim's manufacturing year or exact variant. The length has not been independently checked and its wheel/side was not specified. Hubs, lacing, spoke count, spoke model and current tension remain unconfirmed.

[Kona's 2019 specification](https://archive.konaworld.com/archive/2019/process_165.cfm) lists WTB KOM Trail TCS rims, Formula hubs and stainless black 14-gauge spokes. These are factory specifications, not evidence for the later wheel rebuild. The preset therefore leaves spoke material, shape and dimensions unknown and asks the owner to enter the actual count. Front and rear are separate profiles; each still has separate left/right configurations.

## Manufacturer rim information

[Race Face's AR Offset product page](https://www.raceface.com/products/ar-offset-rim) and its linked [rim dimension sheet](https://cdn.shopify.com/s/files/1/0300/4563/4693/files/RF_Rim_Dimensions_Sheet_-_current.pdf?v=1668639818) describe **AR Offset 35**: 32 holes, 35 mm internal width, 4.5 mm offset, and 562 mm ERD for 27.5 inches. The sheet assumes a 2 mm nipple head for ERD. Its listed maximum spoke tension is **1200 N**, approximately **122 kgf**.

Those figures apply only after the installed rim is confirmed to be that variant. The maximum is a rim limit, not a build target or frequency recommendation. Neither ERD nor the 27.5-inch wheel-size label is a spoke's vibrating length. No ERD, maximum tension, hole count or spoke gauge is automatically assigned by this preset.

## What frequency should Measure show?

The app's provisional detection range is 80–2500 Hz; it is not an acceptable-tension range. No manufacturer-provided target frequency was identified for this rebuilt wheel.

For an **illustrative ideal uniform string only**, invert `T = 4 μ L² f²` to get `f = sqrt(T / μ) / (2 L)`. Assuming steel density 7850 kg/m³, 2.0 mm diameter, 280 mm vibrating length and an arbitrary 1000 N force yields about **360 Hz**. This is not a recommendation for this bike. Changing the length, section, tension, contact or harmonic changes the result. The actual build could sound differently without that alone proving incorrect tension. See the [pitch derivation](https://sheldonbrown.com/pitch-equation.html) and [phase-one research](../PHASE_1_PLAN.md) for assumptions and coupled-spoke limitations.

Start by logging the wheel unchanged in a quiet room. Let a gentle pluck decay before repeating, save three consistent readings and optionally five for a sound reference. Do not tighten the wheel toward the illustrative value. A mechanically verified reference and independent validation are needed before assigning structural tension targets.

## In the app

Open **Wheels → Add wheel → Start from a preset → Kona Process 165 (2019)**. Select front or rear, enter the confirmed count, record the tire state, and leave uncertain dimensions blank. Repeat for the other wheel if applicable. The preset survives local storage and JSON export; equipment identity is included in the saved reading configuration used by CSV exports. Existing profiles and their reference fingerprints remain compatible.

## Experimental tension calculator

At the owner's request, the Measure page provides an **unvalidated ideal-string estimate** for the Kona preset. Kona's published stainless 14g specification supplies a nominal gauge reference; [Sapim's gauge table](https://www.sapim.be/sites/default/files/DOW3%20Sapim_produc_fiche.pdf) identifies 14G as 2.0 mm. Neither source establishes the rebuilt wheel's actual spokes, uniform shaft, density or vibrating endpoints. Uniform 2.0 mm steel and **7850 kg/m³** are explicit modelling assumptions. Butted spokes can also have 2.0 mm ends, as illustrated in [Sapim's brochure](https://www.sapim.be/sites/default/files/Sapim%20brochure%20def%20A5%202018-LR.pdf).

In **Measure → Experimental tension → Set length & assumptions**, the dialog prefills the owner's **272 mm**, preserves decimal edits, and requires acknowledging the assumptions before applying them to the selected wheel side. It does not overwrite measured profile dimensions. A crossing is not automatically a fixed endpoint, and nominal spoke length may differ from vibrating length.

The calculation is `μ = ρπd²/4`, `T = 4μL²f²`, with metres, kg/m³, Hz and newtons; `kgf = N / 9.80665`. For **350 Hz**, **272 mm**, **2.0 mm** and **7850 kg/m³**, this gives **894.03 N ≈ 91.17 kgf**. This worked example is not a recommended pitch or tension. Errors in frequency, length and diameter each enter quadratically; the model omits stiffness and crossing interactions and has no established physical accuracy.

Estimates require three consistent harmonic-supported fundamental readings and a profile explicitly marked **individual**. Unknown/coupled contact, spectral peaks, butted/bladed profiles or conflicting material/diameter remain frequency-only. Applying a model clears previous plucks; changing wheel, side or configuration requires matching saved assumptions. **Return to frequency only** disables the current model. Saved readings retain immutable frequency/assumption snapshots; JSON and CSV mark results `unvalidated-ideal-string`. Independent mechanical validation remains required before relying on absolute tension.

Widget-rendered previews: [setup dialog](previews/kona-assumptions.png) and [example calculation](previews/kona-tension.png). The latter uses injected 350 Hz test readings, not a recording of the owner's wheel.
