# VAI texture artwork (generator)

The decorative SVGs in `src/components/texture/*.astro` are original artwork, generated deterministically by these scripts (fixed random seed,
no external data, nothing traced from any other source).

- `gen.py`  geometry: Signature Geometry (sweep ribbon, blade family, offset arcs, crescent), Reasoning Lines (flow / network / converge),
            the canine thoracic-limb plate (Anatomical Ghost) and the growth-ring contours (Organic Science).
- `emit.py` turns that geometry into the SVG markup embedded in the Astro components (`python3 scripts/texture-art/emit.py` prints sizes).

Changing the artwork means editing `gen.py`, re-emitting, and pasting the new markup into the component's `ART` constant. Intensity and
placement are CSS only (the "VAI TEXTURE SYSTEM" block in `src/styles/global.css`), so they can be tuned without touching the drawings.
