#!/usr/bin/env bash
# Regenerates the highlighted sources in readme/: an SVG and a page per GD++ file, and index.md.
# Run from anywhere: `make readme` or `readme/generate.sh`.
set -euo pipefail

cd "$(dirname "$0")/.."
src=addons/foliage_3d/src
out=readme

rm -f "$out"/*.svg "$out"/*.md

for f in "$src"/*.gd++; do
  name=$(basename "$f")
  base=${name%.gd++}
  gd++ -n --notty cat --svg "$f" > "$out/$base.svg"
  cat > "$out/$base.md" <<EOF
# $name

[Up: all files](index.md) · [Source](../$f)

![$name]($base.svg)
EOF
done

{
  cat <<EOF
# Foliage3D sources

[Back to the README](../README.md)

The GD++ sources of the addon, from [\`$src\`](../$src), highlighted:

EOF
  for f in "$src"/*.gd++; do
    name=$(basename "$f")
    echo "- [\`$name\`](${name%.gd++}.md)"
  done
} > "$out/index.md"
