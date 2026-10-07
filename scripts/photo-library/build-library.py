#!/usr/bin/env python3
"""Photography library pipeline.

Source images (the curated 1024px set; kept OUT of the repo because of size) -> responsive WebP files in public/photography/library/.
  python3 scripts/photo-library/build-library.py --src /path/to/unzipped/Archive            # ids marked "process": true in sources.json
  python3 scripts/photo-library/build-library.py --src /path/to/Archive --all              # every image
  python3 scripts/photo-library/build-library.py --src /path/to/Archive --ids a-b c-d      # specific ids

Output per id:  {id}-480.webp  {id}-800.webp  {id}-1024.webp  (square, uncropped: crops are done in CSS with per-image focal points from
src/lib/photography/library.ts so the same file serves portrait, landscape and square placements).
Treatment is deliberately minimal: resize + EXIF strip + WebP q=78. No colour grading here; the shared look comes from the .ph CSS treatment.
"""
import argparse, json, os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "public", "photography", "library")
WIDTHS = (480, 800, 1024)

ap = argparse.ArgumentParser()
ap.add_argument("--src", required=True)
ap.add_argument("--all", action="store_true")
ap.add_argument("--ids", nargs="*")
a = ap.parse_args()

sources = json.load(open(os.path.join(os.path.dirname(__file__), "sources.json")))
ids = a.ids or [i for i, v in sources.items() if a.all or v["process"]]
os.makedirs(OUT, exist_ok=True)
total = 0
for i in ids:
    path = os.path.join(a.src, sources[i]["source"])
    if not os.path.exists(path):
        sys.exit(f"missing source for {i}: {path}")
    im = Image.open(path).convert("RGB")
    if im.width != im.height:
        sys.exit(f"{i}: expected a square source, got {im.size}")
    for w in WIDTHS:
        r = im if im.width <= w else im.resize((w, w), Image.LANCZOS)
        if im.width < w:  # never upscale
            continue
        dest = os.path.join(OUT, f"{i}-{w}.webp")
        r.save(dest, "WEBP", quality=78, method=6)
        total += os.path.getsize(dest)
    print(f"ok {i}")
print(f"{len(ids)} images, {total/1024/1024:.2f} MB")
