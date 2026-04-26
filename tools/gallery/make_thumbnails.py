#!/usr/bin/env python3
"""Generate JPEG thumbnails of full-resolution gallery PNGs.

Usage:
    make_thumbnails.py <src_dir> [--out-dir thumbs] [--max-px 400] [--quality 82]

For each *.png in src_dir (excluding the thumbnail subdir and known
non-design images), writes <stem>.jpg to src_dir/<out_dir>/.
"""
import argparse
from pathlib import Path

from PIL import Image

EXCLUDE = {"HighTideFLOW.png", "lighthouse.png"}


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("src_dir", type=Path)
    p.add_argument("--out-dir", default="thumbs")
    p.add_argument("--max-px", type=int, default=400)
    p.add_argument("--quality", type=int, default=82)
    args = p.parse_args()

    out_dir = args.src_dir / args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    count = 0
    for png in sorted(args.src_dir.glob("*.png")):
        if png.name in EXCLUDE:
            continue
        with Image.open(png) as im:
            im.thumbnail((args.max_px, args.max_px), Image.LANCZOS)
            if im.mode in ("P", "LA"):
                im = im.convert("RGBA")
            if im.mode == "RGBA":
                bg = Image.new("RGB", im.size, (0, 0, 0))
                bg.paste(im, mask=im.split()[3])
                im = bg
            elif im.mode != "RGB":
                im = im.convert("RGB")
            out = out_dir / (png.stem + ".jpg")
            im.save(out, "JPEG", quality=args.quality, optimize=True)
        count += 1
    print(f"Generated {count} thumbnails in {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
