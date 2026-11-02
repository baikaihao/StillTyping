"""Regenerate the vector identity and transparent raster exports on macOS.

Requires Python package Pillow and Node package @resvg/resvg-js. Typography is converted to paths
with CoreText; the finished SVG files do not depend on system fonts.
"""

from pathlib import Path
import json
import subprocess
import xml.etree.ElementTree as ET

from PIL import Image

ROOT = Path(__file__).resolve().parent
INK = "#202321"
GREEN = "#C5F36B"
PAPER = "#F7F7F2"
WHITE = "#FFFFFF"
MUTED = "#7A7E77"

TYPE = json.loads(subprocess.check_output(["swift", str(ROOT / "outline-type.swift")]))


def text(key, x, y, color=INK, scale=1):
    return f'<path fill="{color}" transform="translate({x} {y}) scale({scale})" d="{TYPE[key]["d"]}"/>'


def mark(arrow=INK, cursor=GREEN):
    # A tall insertion caret stops the Return arrow before it becomes a send.
    return f'''<rect x="38" y="46" width="22" height="164" rx="11" fill="{cursor}"/>
    <path d="M207 68 V117 Q207 140 184 140 H100 M135 105 L100 140 L135 175"
      fill="none" stroke="{arrow}" stroke-width="22" stroke-linecap="round" stroke-linejoin="round"/>'''


def icon_defs():
    return '''<linearGradient id="key-face" x1="0" y1="0" x2="0.9" y2="1">
      <stop stop-color="#353B35"/><stop offset="0.55" stop-color="#242925"/>
      <stop offset="1" stop-color="#191D1A"/></linearGradient>
    <linearGradient id="key-edge" x1="0" y1="0" x2="0" y2="1">
      <stop stop-color="#60685E"/><stop offset="1" stop-color="#161A17"/></linearGradient>'''


def icon():
    # The 1024 canvas retains transparent outer padding for a macOS icon.
    return f'''<rect x="64" y="75" width="896" height="896" rx="204" fill="#0B100D" opacity="0.12"/>
    <rect x="64" y="59" width="896" height="896" rx="204" fill="#141915"/>
    <rect x="64" y="53" width="896" height="886" rx="204" fill="url(#key-edge)"/>
    <rect x="70" y="59" width="884" height="874" rx="199" fill="url(#key-face)"/>
    <path d="M271 64 H753 C861 64 949 152 949 260" fill="none" stroke="#FFFFFF" stroke-opacity="0.13" stroke-width="2"/>
    <g transform="translate(132 118) scale(3)">{mark(WHITE)}</g>'''


def svg(width, height, body, defs="", label="StillTyping!!! logo"):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-label="{label}">
    <title>{label}</title><defs>{defs}</defs>{body}</svg>'''


def write(name, source, png_size=None):
    ET.fromstring(source)
    (ROOT / f"{name}.svg").write_text(source + "\n")
    if png_size:
        subprocess.run(["node", str(ROOT / "render-svg.cjs"), str(ROOT / f"{name}.png"), str(png_size)],
                       input=source.encode(), check=True)


write("stilltyping-mark", svg(256, 256, mark()), 1024)
write("stilltyping-mark-dark", svg(256, 256, mark(WHITE)), 1024)
write("stilltyping-mark-mono", svg(256, 256, mark(INK, INK)), 1024)
write("stilltyping-mark-white", svg(256, 256, mark(WHITE, WHITE)), 1024)
write("stilltyping-app-icon", svg(1024, 1024, icon(), icon_defs()), 1024)


def wordmark(color=INK):
    return text("wordmark", 0, 100, color) + text("punctuation", TYPE["wordmark"]["width"] + 3, 100, GREEN)


word_width = round(TYPE["wordmark"]["width"] + TYPE["punctuation"]["width"] + 8)
write("stilltyping-wordmark", svg(word_width + 16, 132, f'<g transform="translate(8 0)">{wordmark()}</g>'), 2400)
lockup_width = word_width + 184
write("stilltyping-logo", svg(lockup_width, 180,
    f'<g transform="translate(4 0) scale(0.65)">{mark()}</g><g transform="translate(182 12)">{wordmark()}</g>'), 2400)
write("stilltyping-logo-dark", svg(lockup_width, 180,
    f'<g transform="translate(4 0) scale(0.65)">{mark(WHITE)}</g><g transform="translate(182 12)">{wordmark(WHITE)}</g>'), 2400)

board = f'''<rect width="1600" height="1100" fill="{PAPER}"/>
{text("header", 80, 74, MUTED)}{text("edition", 1323, 74, MUTED, .8)}
<path d="M80 105 H1520" stroke="#DADDD4"/>
<g transform="translate(54 168) scale(.42)">{icon()}</g>
<g transform="translate(588 279) scale(1.15)">{wordmark()}</g>
{text("tagline", 592, 478)}{text("description", 592, 520, MUTED)}
<path d="M80 654 H1520" stroke="#DADDD4"/>
<rect x="80" y="690" width="456" height="260" rx="20" fill="#ECEEE7"/>
{text("primary", 104, 724, MUTED)}
<g transform="translate(218 748) scale(.68)">{mark()}</g>
<rect x="552" y="690" width="456" height="260" rx="20" fill="{INK}"/>
{text("reversed", 576, 724, "#BFC5B9")}
<g transform="translate(690 748) scale(.68)">{mark(WHITE)}</g>
<rect x="1024" y="690" width="496" height="260" rx="20" fill="#ECEEE7"/>
{text("sizes", 1048, 724, MUTED)}
<g transform="translate(1136 796) scale(.07143)">{icon()}</g>
<g transform="translate(1260 815) scale(.035714)">{icon()}</g>
<g transform="translate(1353 825) scale(.017857)">{icon()}</g>
{text("sizeLabels", 1155, 903, MUTED)}
{text("note", 80, 1010, MUTED)}
<circle cx="88" cy="1054" r="8" fill="{INK}"/><circle cx="114" cy="1054" r="8" fill="{GREEN}"/>
{text("palette", 141, 1058, MUTED)}'''
write("stilltyping-preview", svg(1600, 1100, board, icon_defs(), "StillTyping!!! — Cursor + Return visual identity"), 2000)

# Export a complete macOS .icns, including all 1× and 2× raster representations.
iconset = ROOT / "StillTyping.iconset"
iconset.mkdir(exist_ok=True)
source = Image.open(ROOT / "stilltyping-app-icon.png")
for size in [16, 32, 128, 256, 512]:
    source.resize((size, size), Image.Resampling.LANCZOS).save(iconset / f"icon_{size}x{size}.png")
    source.resize((size * 2, size * 2), Image.Resampling.LANCZOS).save(iconset / f"icon_{size}x{size}@2x.png")
subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(ROOT / "StillTyping.icns")], check=True)
print(f"Exported identity to {ROOT}")
