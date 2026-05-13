# Asset placeholders — to be replaced

These binary assets cannot be generated from text/SVG by the build pipeline. Replace each placeholder with the final asset before launch.

## OG Image — `og-image.jpg` (1200×630)

A design source has been created at `/public/og-image.svg`. Convert it to JPG at 1200×630 and save as `/public/og-image.jpg`.

Quick options:
- Open `og-image.svg` in a browser at 1200×630, screenshot, save as JPG.
- Use any online SVG→JPG converter at 1200×630.
- Have the designer produce the final branded artwork using the SVG as a structural reference.

The site already references `og-image.jpg` in `<meta>` tags. As soon as the file exists, LinkedIn / X / WhatsApp / Slack previews will populate.

## Favicon PNG set

`favicon.svg` is in place and works for all modern browsers. PNG fallbacks should be generated from it:

- `/public/favicon-32.png` (32×32)
- `/public/icon-192.png` (192×192)
- `/public/icon-512.png` (512×512)
- `/public/apple-touch-icon.png` (180×180)

Use any favicon generator (e.g. realfavicongenerator.net) — drop in `favicon.svg`, download the bundle, copy the PNGs into `/public/`.

Until the PNGs exist, browsers gracefully fall back to `favicon.svg` (which works in Chrome, Safari, Firefox, Edge). Only iOS home-screen save and some older Android versions will use a default icon.

## Founder portrait

A portrait of Dr. Soheyl Simaei is referenced on the home page Leadership block (when added in P0.9). Drop the studio portrait into `/public/founder-portrait.jpg` (square, ~600×600 minimum, editorial brand tone).

Do **not** use stock or AI-generated faces.
