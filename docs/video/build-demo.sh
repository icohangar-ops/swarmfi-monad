#!/usr/bin/env bash
# Build a ~2.5 minute demo video from dashboard screenshots (no narration track).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SHOTS="$ROOT/docs/screenshots"
OUT="$ROOT/docs/video/swarmfi-monad-demo.mp4"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

command -v ffmpeg >/dev/null || { echo "Install ffmpeg: brew install ffmpeg"; exit 1; }

python3 - "$TMP" "$SHOTS" <<'PY'
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

tmp = Path(sys.argv[1])
shots = Path(sys.argv[2])

def font(size: int, bold: bool = False):
    paths = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial.ttf",
    ]
    for p in paths:
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            continue
    return ImageFont.load_default()

def title_card(path: Path, title: str, subtitle: str):
    img = Image.new("RGB", (1920, 1080), (15, 5, 24))
    draw = ImageDraw.Draw(img)
    tw = draw.textlength(title, font=font(72, True))
    sw = draw.textlength(subtitle, font=font(34))
    draw.text(((1920 - tw) / 2, 460), title, fill=(255, 255, 255), font=font(72, True))
    draw.text(((1920 - sw) / 2, 560), subtitle, fill=(196, 181, 253), font=font(34))
    img.save(path)

def caption_shot(src: Path, dst: Path, caption: str):
    base = Image.open(src).convert("RGB")
    base.thumbnail((1920, 980), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (1920, 1080), (15, 5, 24))
    ox = (1920 - base.width) // 2
    oy = (1080 - base.height) // 2
    canvas.paste(base, (ox, oy))
    draw = ImageDraw.Draw(canvas)
    bar_h = 88
    draw.rectangle((0, 1080 - bar_h, 1920, 1080), fill=(26, 10, 46))
    draw.text((48, 1080 - bar_h + 24), caption, fill=(255, 255, 255), font=font(32))
    canvas.save(dst)

title_card(tmp / "00-intro.png", "SwarmFi on Monad", "Multi-agent oracle · prediction markets · vaults")
title_card(tmp / "05-outro.png", "Monad Testnet · Chain 10143", "Clone · seed · explore the dashboard")

caption_shot(shots / "01-dashboard.png", tmp / "01-dashboard.png", "Live BTC/USD consensus from 3 staked oracle agents")
caption_shot(shots / "02-agents.png", tmp / "02-agents.png", "Register agents, submit prices, run weighted-median consensus")
caption_shot(shots / "03-markets.png", tmp / "03-markets.png", "Binary markets resolved by SwarmOracle feeds")
caption_shot(shots / "04-vaults.png", tmp / "04-vaults.png", "Share-based MON vaults with agent-triggered rebalancing")
PY

segment() {
  local input=$1
  local seconds=$2
  local output=$3
  ffmpeg -y -loop 1 -i "$input" \
    -vf "scale=1920:1080,zoompan=z='min(zoom+0.00035,1.05)':d=$((seconds * 30)):s=1920x1080:fps=30" \
    -t "$seconds" -r 30 -pix_fmt yuv420p -c:v libx264 -preset fast -crf 23 "$output" -loglevel error
}

echo "==> Rendering segments..."
segment "$TMP/00-intro.png" 8 "$TMP/00-intro.mp4"
segment "$TMP/01-dashboard.png" 38 "$TMP/01-dashboard.mp4"
segment "$TMP/02-agents.png" 35 "$TMP/02-agents.mp4"
segment "$TMP/03-markets.png" 35 "$TMP/03-markets.mp4"
segment "$TMP/04-vaults.png" 35 "$TMP/04-vaults.mp4"
segment "$TMP/05-outro.png" 12 "$TMP/05-outro.mp4"

printf "file '%s'\n" "$TMP"/*.mp4 | sort > "$TMP/concat.txt"
echo "==> Concatenating to $OUT ..."
ffmpeg -y -f concat -safe 0 -i "$TMP/concat.txt" -c copy "$OUT" -loglevel error

DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUT")
echo "==> Done: $OUT (${DUR}s)"
