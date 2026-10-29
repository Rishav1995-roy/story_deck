#!/bin/sh
# Regenerates doc/demo.gif and the screenshots in doc/.
# Needs: flutter (FVM works: FLUTTER="fvm spawn 3.47.7"), ffmpeg.
set -e
cd "$(dirname "$0")/.."
FLUTTER_CMD=${FLUTTER:-flutter}
$FLUTTER_CMD test --tags demo tool/demo_gif_test.dart
mkdir -p doc
ffmpeg -y -loglevel error -framerate 15 -i build/demo_frames/frame_%04d.png \
  -vf "scale=360:-1:flags=lanczos,palettegen=max_colors=96:stats_mode=diff" build/palette.png
ffmpeg -y -loglevel error -framerate 15 -i build/demo_frames/frame_%04d.png -i build/palette.png \
  -lavfi "scale=360:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
  -loop 0 doc/demo.gif
ls -l doc/demo.gif
