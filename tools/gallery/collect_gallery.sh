#!/usr/bin/env bash
# Build all gallery images and copy them to a destination directory.
#
# Usage:
#   tools/gallery/collect_gallery.sh [dest_dir]
#
# Default dest_dir is ../webpage/figures relative to the repo root.
# Each image is renamed <leaf>_<platform>.png. Also generates JPEG
# thumbnails under <dest_dir>/thumbs/ for the gallery page.

set -euo pipefail

dest_dir="${1:-../webpage/figures}"
mkdir -p "$dest_dir"

# Enumerate all *_gallery targets across designs and build them together.
# --keep_going so a broken design doesn't block the rest.
mapfile -t targets < <(bazel query 'filter(".*_gallery$", //designs/...)' 2>/dev/null)
if [[ ${#targets[@]} -eq 0 ]]; then
    echo "No _gallery targets found under //designs/..." >&2
    exit 1
fi

bazel build --keep_going "${targets[@]}" || true

shopt -s globstar nullglob
copied=0
for img in bazel-bin/designs/**/*_gallery.png; do
    rel="${img#bazel-bin/designs/}"
    platform="${rel%%/*}"
    rest="${rel#*/}"
    pkg_dir=$(dirname "$rest")
    leaf="${pkg_dir##*/}"
    out="$dest_dir/${leaf}_${platform}.png"
    if [[ -s "$img" ]]; then
        cp -f "$img" "$out"
        echo "  $out"
        copied=$((copied + 1))
    fi
done

echo "Copied $copied gallery images to $dest_dir"

# Generate JPEG thumbnails for the gallery page.
script_dir="$(cd "$(dirname "$0")" && pwd)"
python3 "$script_dir/make_thumbnails.py" "$dest_dir"
