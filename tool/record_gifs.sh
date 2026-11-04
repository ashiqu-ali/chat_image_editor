#!/usr/bin/env bash
# Records the GIF previews in doc/gifs/ from the example app on an iOS
# simulator and, with --screenshots, refreshes the PNGs in doc/screenshots/.
#
# Usage, from anywhere in the repository, with an iOS simulator booted:
#
#   tool/record_gifs.sh [--screenshots] [--no-gifs] [scenario ...]
#
# Scenarios: chat draw text crop compress (default: all). Each one becomes
# doc/gifs/<scenario>.gif. --screenshots also refreshes doc/screenshots/ with
# integration_test/screenshots_test.dart and --no-gifs skips the GIFs, so
# `tool/record_gifs.sh --screenshots --no-gifs` only refreshes screenshots.
#
# Environment:
#   DEVICE   simulator UDID or name (default: the first booted simulator)
#   WIDTH    GIF width in pixels (default: 360)
#   FPS      GIF frame rate (default: 15)
#   FFMPEG   ffmpeg binary (default: ffmpeg on the PATH)
#
# Needs Xcode (xcrun simctl), fvm and ffmpeg. The raw recording, the logs and
# the intermediate clips are kept in example/build/gifs/.
#
# How it works: example/integration_test/demo_recording_test.dart drives each
# scenario in the example chat at a human pace while `simctl io recordVideo`
# records the screen. The test flashes the screen magenta right before and
# right after each scenario. This script finds those flashes in the
# recording, keeps what's between them and turns each clip into a looping GIF
# with a two-pass palette.
set -euo pipefail

all=(chat draw text crop compress)

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
example="$root/example"
work="$example/build/gifs"
out="$root/doc/gifs"
width="${WIDTH:-360}"
fps="${FPS:-15}"
ffmpeg="${FFMPEG:-ffmpeg}"
ffprobe="$(dirname "$(command -v "$ffmpeg" || echo ffmpeg)")/ffprobe"

# Frame rate the recording is resampled to before it's cut. The simulator
# records only when the screen changes, so this also fills the still parts.
cut_fps=30

die() {
  echo "record_gifs: $*" >&2
  exit 1
}

usage() {
  sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed -E 's/^# ?//'
}

screenshots=false
gifs=true
requested=()
for arg in "$@"; do
  case "$arg" in
    --screenshots) screenshots=true ;;
    --no-gifs) gifs=false ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*) die "unknown option $arg (see --help)" ;;
    *) requested+=("$arg") ;;
  esac
done

for name in ${requested[@]+"${requested[@]}"}; do
  [[ " ${all[*]} " == *" $name "* ]] ||
    die "unknown scenario '$name' (pick from: ${all[*]})"
done

# The test runs scenarios in this order, so the clips come out in it too.
scenarios=()
for name in "${all[@]}"; do
  $gifs || break
  if [ ${#requested[@]} -eq 0 ] || [[ " ${requested[*]} " == *" $name "* ]]; then
    scenarios+=("$name")
  fi
done

command -v xcrun >/dev/null || die "needs Xcode's command line tools (xcrun)"
command -v fvm >/dev/null || die "needs fvm (https://fvm.app)"
command -v "$ffmpeg" >/dev/null || die "needs ffmpeg (brew install ffmpeg)"
[ -x "$ffprobe" ] || ffprobe="ffprobe"

uuid='[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}'
device="${DEVICE:-}"
if [ -z "$device" ]; then
  device="$(xcrun simctl list devices booted | grep -Eo "$uuid" | head -n 1 || true)"
  [ -n "$device" ] || die "no booted simulator; boot one or set DEVICE"
elif ! [[ "$device" =~ ^$uuid$ ]]; then
  name="$device"
  device="$(xcrun simctl list devices | grep -F "$name (" | grep -Eo "$uuid" | head -n 1 || true)"
  [ -n "$device" ] || die "no simulator named '$name'"
fi

mkdir -p "$work" "$out"

# The classic status bar and a light appearance, the same on every run.
xcrun simctl status_bar "$device" override --time 9:41 \
  --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl ui "$device" appearance light

if [ ${#scenarios[@]} -gt 0 ]; then
  movie="$work/recording.mov"
  rm -f "$movie" "$work/record.log"

  xcrun simctl io "$device" recordVideo --codec=h264 --force "$movie" \
    >"$work/record.log" 2>&1 &
  recorder=$!
  stop_recording() {
    if kill -0 "$recorder" 2>/dev/null; then
      kill -INT "$recorder"
      wait "$recorder" || true
    fi
  }
  trap stop_recording EXIT
  for _ in $(seq 1 100); do
    grep -q 'Recording started' "$work/record.log" && break
    sleep 0.1
  done
  grep -q 'Recording started' "$work/record.log" ||
    die "the screen recording didn't start (see $work/record.log)"

  csv="$(IFS=,; echo "${scenarios[*]}")"
  echo "Recording ${scenarios[*]} on $device…"
  if ! (cd "$example" && fvm flutter drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/demo_recording_test.dart \
    --dart-define=SCENARIO="$csv" \
    -d "$device") 2>&1 | tee "$work/drive.log"; then
    die "the walkthrough failed (see $work/drive.log)"
  fi
  stop_recording
  trap - EXIT
  [ -s "$movie" ] || die "no recording was written (see $work/record.log)"

  # Runs of magenta frames, as "first last" frame numbers at $cut_fps: each
  # frame scaled down to one averaged pixel.
  runs=()
  while read -r first last; do
    runs+=("$first" "$last")
  done < <(
    "$ffmpeg" -v error -i "$movie" \
      -vf "fps=$cut_fps,scale=1:1:flags=area,format=rgb24" -f rawvideo - |
      od -An -v -tu1 |
      awk '
        {
          for (i = 1; i <= NF; i++) {
            c[n % 3] = $i
            n++
            if (n % 3) continue
            frame = n / 3 - 1
            magenta = c[0] > 180 && c[1] < 90 && c[2] > 180
            if (magenta && !run) { start = frame; run = 1 }
            else if (!magenta && run) { print start, frame - 1; run = 0 }
          }
        }
        END { if (run) print start, n / 3 - 1 }
      '
  )
  expected=$((${#scenarios[@]} * 2))
  found=$((${#runs[@]} / 2))
  [ "$found" -eq "$expected" ] ||
    die "found $found marker flashes in the recording, expected $expected"

  printf '\n%-10s %9s %9s %11s\n' GIF duration size dimensions
  for i in "${!scenarios[@]}"; do
    name="${scenarios[$i]}"
    begin=$((runs[i * 4 + 1] + 1)) # first frame after the opening flash
    end=${runs[i * 4 + 2]}         # first frame of the closing flash
    clip="$work/$name.mkv"
    palette="$work/$name-palette.png"
    gif="$out/$name.gif"

    "$ffmpeg" -v error -y -i "$movie" \
      -vf "fps=$cut_fps,trim=start_frame=$begin:end_frame=$end,setpts=PTS-STARTPTS,fps=$fps,scale=$width:-1:flags=lanczos" \
      -c:v ffv1 "$clip"
    "$ffmpeg" -v error -y -i "$clip" \
      -vf "palettegen=max_colors=256:stats_mode=full" "$palette"
    "$ffmpeg" -v error -y -i "$clip" -i "$palette" \
      -lavfi "[0:v][1:v]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
      -loop 0 "$gif"

    duration="$("$ffprobe" -v error -show_entries format=duration -of csv=p=0 "$gif")"
    size="$(wc -c <"$gif" | tr -d ' ')"
    dimensions="$("$ffprobe" -v error -select_streams v -show_entries stream=width,height -of csv=s=x:p=0 "$gif")"
    printf '%-10s %8.1fs %8.2fM %11s\n' "$name.gif" "$duration" \
      "$(echo "$size / 1048576" | bc -l)" "$dimensions"
  done
  echo
fi

if $screenshots; then
  echo "Capturing screenshots…"
  (cd "$example" && fvm flutter drive \
    --driver=test_driver/screenshot_driver.dart \
    --target=integration_test/screenshots_test.dart \
    -d "$device")
  for png in "$root"/doc/screenshots/*.png; do
    sips -Z 1080 "$png" >/dev/null
    printf '%-16s %6d KB\n' "$(basename "$png")" "$(($(wc -c <"$png") / 1024))"
  done
fi
