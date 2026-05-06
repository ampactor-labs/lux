#!/usr/bin/env python3
"""
Mentl Mono — Build Script

Derives Mentl Mono from JetBrains Mono by:
1. Renaming all font metadata
2. Drawing 16 custom ligature glyphs (geometric/angular Incan style)
3. Compiling OpenType calt features for ligature substitution

Requires: fonttools (pip install fonttools)

Usage:
    python3 build.py [--input-dir DIR] [--output-dir DIR]
"""

import copy
import os
import sys
from pathlib import Path

from fontTools.ttLib import TTFont
from fontTools.feaLib.builder import addOpenTypeFeatures
from fontTools.pens.ttGlyphPen import TTGlyphPen

# ─── Configuration ───────────────────────────────────────────────

FONT_DIR = Path(os.path.expanduser("~/.local/share/fonts"))
SCRIPT_DIR = Path(__file__).parent
OUTPUT_DIR = SCRIPT_DIR / "output"
FEA_FILE = SCRIPT_DIR / "features.fea"

# JetBrains Mono source files → Mentl Mono output files
VARIANTS = {
    "JetBrainsMono-Regular.ttf":    "InkaMono-Regular.ttf",
    "JetBrainsMono-Bold.ttf":       "InkaMono-Bold.ttf",
    "JetBrainsMono-Italic.ttf":     "InkaMono-Italic.ttf",
    "JetBrainsMono-BoldItalic.ttf": "InkaMono-BoldItalic.ttf",
}

# Font metrics (from JetBrains Mono)
UPM = 1000
CHAR_W = 600      # monospace character width
CAP_H = 730       # cap height
X_H = 550         # x-height
BASELINE = 0
MID_Y = 275       # vertical center (math axis ≈ x-height / 2)
BOT_Y = 50        # bottom extent for operator glyphs
TOP_Y = 550       # top extent for operator glyphs (= x-height)
STROKE = 80       # stroke thickness for geometric glyphs
THIN_STROKE = 60  # thinner stroke for detail elements

# ─── Glyph Drawing Functions ────────────────────────────────────
# Each function draws into a TTGlyphPen at the given width.
# Coordinate space: (0,0) = baseline-left, positive Y = up.
# All glyphs use geometric/angular Incan-inspired shapes.

def draw_pipe_forward(pen):
    """
    |> — converge: right-pointing stepped triangle.
    Geometric: angular chevron pointing right.
    Width: 1200 (2 chars)
    """
    w = 1200
    cx, cy = w // 2, MID_Y
    # Right-pointing angular arrow / chevron
    # Left vertical bar
    bar_x = 200
    pen.moveTo((bar_x, BOT_Y))
    pen.lineTo((bar_x + STROKE, BOT_Y))
    pen.lineTo((bar_x + STROKE, TOP_Y))
    pen.lineTo((bar_x, TOP_Y))
    pen.closePath()
    # Right-pointing triangle
    pen.moveTo((bar_x + STROKE + 60, BOT_Y))
    pen.lineTo((w - 180, cy))
    pen.lineTo((bar_x + STROKE + 60, TOP_Y))
    pen.closePath()
    return w

def draw_pipe_diverge(pen):
    """
    <| — diverge: left-pointing stepped triangle.
    Width: 1200
    """
    w = 1200
    cx, cy = w // 2, MID_Y
    # Right vertical bar
    bar_x = w - 200 - STROKE
    pen.moveTo((bar_x, BOT_Y))
    pen.lineTo((bar_x + STROKE, BOT_Y))
    pen.lineTo((bar_x + STROKE, TOP_Y))
    pen.lineTo((bar_x, TOP_Y))
    pen.closePath()
    # Left-pointing triangle
    pen.moveTo((bar_x - 60, BOT_Y))
    pen.lineTo((180, cy))
    pen.lineTo((bar_x - 60, TOP_Y))
    pen.closePath()
    return w

def draw_pipe_compose(pen):
    """
    >< — parallel compose: the BOWTIE / butterfly.
    Mentl's signature glyph. Two triangles meeting at center,
    with stepped geometric edges evoking the chakana.
    Width: 1200
    """
    w = 1200
    cx, cy = w // 2, MID_Y
    half = 50  # gap at center

    # Left triangle: points right to center
    pen.moveTo((120, BOT_Y))
    pen.lineTo((cx - half, cy))
    pen.lineTo((120, TOP_Y))
    pen.closePath()

    # Right triangle: points left to center
    pen.moveTo((w - 120, BOT_Y))
    pen.lineTo((cx + half, cy))
    pen.lineTo((w - 120, TOP_Y))
    pen.closePath()

    # Center diamond accent (stepped Incan motif)
    d = 40
    pen.moveTo((cx, cy - d*2))
    pen.lineTo((cx + d, cy))
    pen.lineTo((cx, cy + d*2))
    pen.lineTo((cx - d, cy))
    pen.closePath()

    return w

def draw_pipe_tee(pen):
    """
    ~> — tee (handler attach): smooth squiggly arrow pointing right.
    Sine-wave curve flowing into angular arrowhead.
    Width: 1200
    """
    w = 1200
    cy = MID_Y
    s = STROKE // 2
    amp = 90  # wave amplitude
    
    # Build the squiggly line as a thick stroked sine wave
    # We approximate sine with quadratic Beziers: two half-waves
    # Upper edge of the wave stroke
    pen.moveTo((100, cy + s))
    pen.qCurveTo((225, cy + amp + s), (350, cy + s))   # first half-wave up
    pen.qCurveTo((475, cy - amp + s), (600, cy + s))   # second half-wave down
    pen.lineTo((840, cy + s))                            # straight run to arrowhead
    # Lower edge (reverse direction)
    pen.lineTo((840, cy - s))
    pen.lineTo((600, cy - s))
    pen.qCurveTo((475, cy - amp - s), (350, cy - s))   # second half-wave down
    pen.qCurveTo((225, cy + amp - s), (100, cy - s))   # first half-wave up
    pen.closePath()

    # Angular arrowhead
    pen.moveTo((800, BOT_Y + 70))
    pen.lineTo((w - 100, cy))
    pen.lineTo((800, TOP_Y - 70))
    pen.lineTo((800, TOP_Y - 70 - STROKE))
    pen.lineTo((w - 200, cy))
    pen.lineTo((800, BOT_Y + 70 + STROKE))
    pen.closePath()

    return w

def draw_pipe_feedback(pen):
    """
    <~ — feedback (cycle closure): angular arrowhead into smooth squiggly line.
    Mirror of ~> pointing left.
    Width: 1200
    """
    w = 1200
    cy = MID_Y
    s = STROKE // 2
    amp = 90

    # Angular arrowhead pointing left
    pen.moveTo((400, BOT_Y + 70))
    pen.lineTo((100, cy))
    pen.lineTo((400, TOP_Y - 70))
    pen.lineTo((400, TOP_Y - 70 - STROKE))
    pen.lineTo((200, cy))
    pen.lineTo((400, BOT_Y + 70 + STROKE))
    pen.closePath()

    # Squiggly line (left to right, starting from arrowhead connection)
    pen.moveTo((360, cy + s))
    pen.lineTo((600, cy + s))
    pen.qCurveTo((725, cy + amp + s), (850, cy + s))   # first half-wave up
    pen.qCurveTo((975, cy - amp + s), (1100, cy + s))  # second half-wave down
    # Lower edge (reverse)
    pen.lineTo((1100, cy - s))
    pen.qCurveTo((975, cy - amp - s), (850, cy - s))   # second half-wave down
    pen.qCurveTo((725, cy + amp - s), (600, cy - s))   # first half-wave up
    pen.lineTo((360, cy - s))
    pen.closePath()

    return w

def draw_arrow(pen):
    """
    -> — thin arrow (type signatures).
    Clean geometric right arrow.
    Width: 1200
    """
    w = 1200
    cy = MID_Y
    s = THIN_STROKE // 2

    # Horizontal shaft
    pen.moveTo((160, cy - s))
    pen.lineTo((840, cy - s))
    pen.lineTo((840, cy + s))
    pen.lineTo((160, cy + s))
    pen.closePath()

    # Angular arrowhead (hollow chevron)
    pen.moveTo((780, BOT_Y + 90))
    pen.lineTo((w - 140, cy))
    pen.lineTo((780, TOP_Y - 90))
    pen.lineTo((780, TOP_Y - 90 - STROKE))
    pen.lineTo((w - 240, cy))
    pen.lineTo((780, BOT_Y + 90 + STROKE))
    pen.closePath()

    return w

def draw_fat_arrow(pen):
    """
    => — fat arrow (lambdas, match arms).
    Double-lined arrow with bold arrowhead.
    Width: 1200
    """
    w = 1200
    cy = MID_Y
    s = THIN_STROKE // 2
    gap = 50  # gap between double lines

    # Upper horizontal line
    pen.moveTo((160, cy + gap - s))
    pen.lineTo((800, cy + gap - s))
    pen.lineTo((800, cy + gap + s))
    pen.lineTo((160, cy + gap + s))
    pen.closePath()

    # Lower horizontal line
    pen.moveTo((160, cy - gap - s))
    pen.lineTo((800, cy - gap - s))
    pen.lineTo((800, cy - gap + s))
    pen.lineTo((160, cy - gap + s))
    pen.closePath()

    # Bold angular arrowhead
    pen.moveTo((760, BOT_Y + 70))
    pen.lineTo((w - 120, cy))
    pen.lineTo((760, TOP_Y - 70))
    pen.lineTo((760, TOP_Y - 70 - STROKE))
    pen.lineTo((w - 220, cy))
    pen.lineTo((760, BOT_Y + 70 + STROKE))
    pen.closePath()

    return w

def draw_equal_equal(pen):
    """
    == — connected double equal with stepped notch.
    Width: 1200
    """
    w = 1200
    cy = MID_Y
    gap = 60
    s = THIN_STROKE // 2

    # Upper bar (full width with center notch)
    pen.moveTo((120, cy + gap - s))
    pen.lineTo((w - 120, cy + gap - s))
    pen.lineTo((w - 120, cy + gap + s))
    pen.lineTo((120, cy + gap + s))
    pen.closePath()

    # Lower bar
    pen.moveTo((120, cy - gap - s))
    pen.lineTo((w - 120, cy - gap - s))
    pen.lineTo((w - 120, cy - gap + s))
    pen.lineTo((120, cy - gap + s))
    pen.closePath()

    return w

def draw_not_equal(pen):
    """
    != — slashed equal sign.
    Two horizontal bars with diagonal slash through them.
    Width: 1200
    """
    w = 1200
    cy = MID_Y
    gap = 60
    s = THIN_STROKE // 2

    # Upper bar
    pen.moveTo((120, cy + gap - s))
    pen.lineTo((w - 120, cy + gap - s))
    pen.lineTo((w - 120, cy + gap + s))
    pen.lineTo((120, cy + gap + s))
    pen.closePath()

    # Lower bar
    pen.moveTo((120, cy - gap - s))
    pen.lineTo((w - 120, cy - gap - s))
    pen.lineTo((w - 120, cy - gap + s))
    pen.lineTo((120, cy - gap + s))
    pen.closePath()

    # Diagonal slash
    slash_w = 55
    pen.moveTo((w//2 + 120, cy + gap + 100))
    pen.lineTo((w//2 + 120 + slash_w, cy + gap + 100))
    pen.lineTo((w//2 - 120 + slash_w, cy - gap - 100))
    pen.lineTo((w//2 - 120, cy - gap - 100))
    pen.closePath()

    return w

def draw_lte(pen):
    """
    <= — less-than-or-equal.
    Angular less-than with underline.
    Width: 1200
    """
    w = 1200
    cy = MID_Y + 40  # shift up to make room for underline
    s = THIN_STROKE // 2

    # Angular less-than chevron
    pen.moveTo((w - 200, cy + 160))
    pen.lineTo((250, cy))
    pen.lineTo((w - 200, cy - 160))
    pen.lineTo((w - 200, cy - 160 + STROKE))
    pen.lineTo((370, cy))
    pen.lineTo((w - 200, cy + 160 - STROKE))
    pen.closePath()

    # Underline bar
    pen.moveTo((250, 80))
    pen.lineTo((w - 200, 80))
    pen.lineTo((w - 200, 80 + THIN_STROKE))
    pen.lineTo((250, 80 + THIN_STROKE))
    pen.closePath()

    return w

def draw_gte(pen):
    """
    >= — greater-than-or-equal.
    Width: 1200
    """
    w = 1200
    cy = MID_Y + 40
    s = THIN_STROKE // 2

    # Angular greater-than chevron
    pen.moveTo((200, cy + 160))
    pen.lineTo((w - 250, cy))
    pen.lineTo((200, cy - 160))
    pen.lineTo((200, cy - 160 + STROKE))
    pen.lineTo((w - 370, cy))
    pen.lineTo((200, cy + 160 - STROKE))
    pen.closePath()

    # Underline bar
    pen.moveTo((200, 80))
    pen.lineTo((w - 250, 80))
    pen.lineTo((w - 250, 80 + THIN_STROKE))
    pen.lineTo((200, 80 + THIN_STROKE))
    pen.closePath()

    return w

def draw_concat(pen):
    """
    ++ — double plus for concatenation.
    Two interlocking plus signs with shared horizontal bar.
    Width: 1200
    """
    w = 1200
    cy = MID_Y
    s = THIN_STROKE // 2
    arm = 140  # length of vertical arms

    # Shared horizontal bar spanning both
    pen.moveTo((140, cy - s))
    pen.lineTo((w - 140, cy - s))
    pen.lineTo((w - 140, cy + s))
    pen.lineTo((140, cy + s))
    pen.closePath()

    # Left vertical bar
    lx = w // 2 - 180
    pen.moveTo((lx - s, cy - arm))
    pen.lineTo((lx + s, cy - arm))
    pen.lineTo((lx + s, cy + arm))
    pen.lineTo((lx - s, cy + arm))
    pen.closePath()

    # Right vertical bar
    rx = w // 2 + 180
    pen.moveTo((rx - s, cy - arm))
    pen.lineTo((rx + s, cy - arm))
    pen.lineTo((rx + s, cy + arm))
    pen.lineTo((rx - s, cy + arm))
    pen.closePath()

    return w

def draw_logical_and(pen):
    """
    && — double ampersand, geometric angular AND.
    Two overlapping chevrons pointing up.
    Width: 1200
    """
    w = 1200
    cy = MID_Y
    s = THIN_STROKE

    # Left upward chevron
    pen.moveTo((140, BOT_Y + 90))
    pen.lineTo((140 + s, BOT_Y + 90))
    pen.lineTo((w//2 - 60, TOP_Y - 70))
    pen.lineTo((w//2 - 60 - s, TOP_Y - 70))
    pen.closePath()

    pen.moveTo((w//2 - 60, TOP_Y - 70))
    pen.lineTo((w//2 - 60 + s, TOP_Y - 70))
    pen.lineTo((w//2 + 200, BOT_Y + 90))
    pen.lineTo((w//2 + 200 - s, BOT_Y + 90))
    pen.closePath()

    # Right upward chevron
    pen.moveTo((w//2 - 200, BOT_Y + 90))
    pen.lineTo((w//2 - 200 + s, BOT_Y + 90))
    pen.lineTo((w//2 + 60, TOP_Y - 70))
    pen.lineTo((w//2 + 60 - s, TOP_Y - 70))
    pen.closePath()

    pen.moveTo((w//2 + 60, TOP_Y - 70))
    pen.lineTo((w//2 + 60 + s, TOP_Y - 70))
    pen.lineTo((w - 140, BOT_Y + 90))
    pen.lineTo((w - 140 - s, BOT_Y + 90))
    pen.closePath()

    return w

def draw_logical_or(pen):
    """
    || — double pipe, geometric angular OR.
    Two parallel vertical bars with angular feet.
    Width: 1200
    """
    w = 1200
    cy = MID_Y
    s = THIN_STROKE // 2

    # Left bar
    lx = w // 2 - 140
    pen.moveTo((lx - s, BOT_Y))
    pen.lineTo((lx + s, BOT_Y))
    pen.lineTo((lx + s, TOP_Y))
    pen.lineTo((lx - s, TOP_Y))
    pen.closePath()

    # Right bar
    rx = w // 2 + 140
    pen.moveTo((rx - s, BOT_Y))
    pen.lineTo((rx + s, BOT_Y))
    pen.lineTo((rx + s, TOP_Y))
    pen.lineTo((rx - s, TOP_Y))
    pen.closePath()

    return w

def draw_namespace(pen):
    """
    :: — stacked double colon for namespace paths.
    Four dots arranged in a 2x2 grid.
    Width: 1200
    """
    w = 1200
    cy = MID_Y
    dot_r = 50  # dot radius (actually half-side for square dots)

    positions = [
        (w//2 - 160, cy + 120),  # top-left
        (w//2 + 160, cy + 120),  # top-right
        (w//2 - 160, cy - 120),  # bottom-left
        (w//2 + 160, cy - 120),  # bottom-right
    ]

    for (dx, dy) in positions:
        # Diamond-shaped dot (geometric/angular)
        pen.moveTo((dx, dy - dot_r))
        pen.lineTo((dx + dot_r, dy))
        pen.lineTo((dx, dy + dot_r))
        pen.lineTo((dx - dot_r, dy))
        pen.closePath()

    return w

def draw_hole(pen):
    """
    ?? — hole / socket (Primitive #8: productive under error).
    A hollow octagonal socket — like a circuit board pad
    waiting to receive a component. Visually invites the user
    (and Mentl) to plug something into it.
    Width: 1200 (2-char ligature for ??)
    """
    w = 1200
    cx, cy = w // 2, MID_Y
    s = STROKE  # wall thickness

    # Octagonal socket outline (outer)
    r_out = 220  # outer radius — bigger at 1200w
    r_in = r_out - s  # inner radius

    import math
    n_sides = 8
    angle_offset = math.pi / 8  # rotate 22.5° so flat side is at top

    # Outer octagon
    pts_out = []
    for i in range(n_sides):
        angle = angle_offset + (2 * math.pi * i / n_sides)
        px = cx + int(r_out * math.cos(angle))
        py = cy + int(r_out * math.sin(angle))
        pts_out.append((px, py))

    # Inner octagon (the hollow)
    pts_in = []
    for i in range(n_sides):
        angle = angle_offset + (2 * math.pi * i / n_sides)
        px = cx + int(r_in * math.cos(angle))
        py = cy + int(r_in * math.sin(angle))
        pts_in.append((px, py))

    # Draw outer octagon (clockwise)
    pen.moveTo(pts_out[0])
    for pt in pts_out[1:]:
        pen.lineTo(pt)
    pen.closePath()

    # Draw inner octagon (counter-clockwise to create hollow)
    pen.moveTo(pts_in[0])
    for pt in reversed(pts_in[1:]):
        pen.lineTo(pt)
    pen.closePath()

    # Center diamond — the "contact point" of the socket
    dot_r = 40
    dot_pts = []
    for i in range(4):
        angle = math.pi / 4 + (2 * math.pi * i / 4)
        px = cx + int(dot_r * math.cos(angle))
        py = cy + int(dot_r * math.sin(angle))
        dot_pts.append((px, py))
    pen.moveTo(dot_pts[0])
    for pt in dot_pts[1:]:
        pen.lineTo(pt)
    pen.closePath()

    return w


def draw_doc_comment(pen):
    """
    /// — triple slash for doc comments.
    Three connected angular slashes with shared baseline.
    Width: 1800 (3 chars)
    """
    w = 1800
    cy = MID_Y
    s = THIN_STROKE
    slash_h = 360
    spacing = 400

    for i in range(3):
        x_off = 200 + i * spacing
        # Each slash is a parallelogram
        pen.moveTo((x_off + 100, cy - slash_h // 2))
        pen.lineTo((x_off + 100 + s, cy - slash_h // 2))
        pen.lineTo((x_off - 100 + s, cy + slash_h // 2))
        pen.lineTo((x_off - 100, cy + slash_h // 2))
        pen.closePath()

    return w


# ─── Glyph Registry ─────────────────────────────────────────────

LIGATURE_GLYPHS = {
    "pipe_forward":  draw_pipe_forward,
    "pipe_diverge":  draw_pipe_diverge,
    "pipe_compose":  draw_pipe_compose,
    "pipe_tee":      draw_pipe_tee,
    "pipe_feedback": draw_pipe_feedback,
    "arrow":         draw_arrow,
    "fat_arrow":     draw_fat_arrow,
    "equal_equal":   draw_equal_equal,
    "not_equal":     draw_not_equal,
    "lte":           draw_lte,
    "gte":           draw_gte,
    "concat":        draw_concat,
    "logical_and":   draw_logical_and,
    "logical_or":    draw_logical_or,
    "namespace":     draw_namespace,
    "doc_comment":   draw_doc_comment,
    "hole":          draw_hole,          # ?? → octagonal socket
}

# No single-char replacements — ? stays as normal question mark
GLYPH_REPLACEMENTS = {}


# ─── Font Metadata Renaming ─────────────────────────────────────

def rename_font(font, variant_style):
    """
    Replace all JetBrains Mono references with Mentl Mono.
    Compliant with SIL OFL derivative requirements.
    """
    name_table = font["name"]

    replacements = {
        0: f"Copyright 2020 The JetBrains Mono Project Authors. "
           f"Modified 2026 Ampactor Labs (Mentl Mono derivative). "
           f"Licensed under SIL Open Font License 1.1.",
        1: "Mentl Mono",
        2: variant_style,
        3: f"1.0;AmpactorLabs;InkaMono-{variant_style.replace(' ', '')}",
        4: f"Mentl Mono {variant_style}",
        5: "Version 1.0 — derived from JetBrains Mono 2.304 with Mentl-specific ligatures",
        6: f"InkaMono-{variant_style.replace(' ', '')}",
        7: "Mentl Mono",
        8: "Ampactor Labs",
        9: "Philipp Nurullin, Konstantin Bulenkov (JetBrains Mono); Ampactor Labs (Mentl ligatures)",
        11: "https://github.com/ampactor-labs/inka",
        12: "https://github.com/ampactor-labs/inka",
        13: "This Font Software is licensed under the SIL Open Font License, Version 1.1.",
        14: "https://openfontlicense.org",
        16: "Mentl Mono",
        17: variant_style,
    }

    # Update all platforms
    for record in name_table.names:
        if record.nameID in replacements:
            record.string = replacements[record.nameID]


# ─── Main Build ──────────────────────────────────────────────────

def build_variant(input_path, output_path, variant_style):
    """Build one Mentl Mono variant from a JetBrains Mono source."""
    print(f"\n{'='*60}")
    print(f"Building: {output_path.name}")
    print(f"  Source: {input_path.name}")
    print(f"  Style:  {variant_style}")
    print(f"{'='*60}")

    font = TTFont(str(input_path))

    # Step 1: Rename metadata
    print("  [1/4] Renaming font metadata...")
    rename_font(font, variant_style)

    # Step 2: Add ligature glyphs
    print("  [2/4] Drawing ligature glyphs...")
    glyf_table = font["glyf"]
    hmtx_table = font["hmtx"]
    glyph_order = font.getGlyphOrder()

    for glyph_name, draw_fn in LIGATURE_GLYPHS.items():
        pen = TTGlyphPen(font.getGlyphSet())
        width = draw_fn(pen)
        glyph = pen.glyph()

        # Add glyph to tables
        glyf_table[glyph_name] = glyph
        hmtx_table[glyph_name] = (width, 0)

        if glyph_name not in glyph_order:
            glyph_order.append(glyph_name)

        print(f"    ✓ {glyph_name} (width={width})")

    # Step 2b: Replace existing glyphs (single-char overrides)
    if GLYPH_REPLACEMENTS:
        print("  [2b/4] Replacing glyph overrides...")
        for glyph_name, draw_fn in GLYPH_REPLACEMENTS.items():
            pen = TTGlyphPen(font.getGlyphSet())
            width = draw_fn(pen)
            glyph = pen.glyph()
            glyf_table[glyph_name] = glyph
            hmtx_table[glyph_name] = (width, hmtx_table[glyph_name][1])
            print(f"    ✓ {glyph_name} → replaced (width={width})")
    else:
        print("  [2b/4] No glyph overrides.")

    font.setGlyphOrder(glyph_order)

    # Update maxp table
    font["maxp"].numGlyphs = len(glyph_order)

    # Step 3: Compile OpenType features
    print("  [3/4] Compiling OpenType features (calt)...")
    addOpenTypeFeatures(font, str(FEA_FILE))
    print("    ✓ GSUB calt feature compiled")

    # Step 4: Save
    print(f"  [4/4] Saving to {output_path}...")
    font.save(str(output_path))
    print(f"    ✓ Saved ({output_path.stat().st_size:,} bytes)")

    font.close()


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Determine variant styles from filenames
    style_map = {
        "Regular": "Regular",
        "Bold": "Bold",
        "Italic": "Italic",
        "BoldItalic": "Bold Italic",
    }

    success = 0
    for input_name, output_name in VARIANTS.items():
        input_path = FONT_DIR / input_name
        output_path = OUTPUT_DIR / output_name

        if not input_path.exists():
            print(f"⚠ Skipping {input_name} — not found at {input_path}")
            continue

        # Determine style
        for key, style in style_map.items():
            if key in input_name:
                variant_style = style
                break
        else:
            variant_style = "Regular"

        try:
            build_variant(input_path, output_path, variant_style)
            success += 1
        except Exception as e:
            print(f"✗ Failed to build {output_name}: {e}")
            import traceback
            traceback.print_exc()

    print(f"\n{'='*60}")
    print(f"Build complete: {success}/{len(VARIANTS)} variants built")
    print(f"Output: {OUTPUT_DIR}")
    print(f"\nTo install:")
    print(f"  cp {OUTPUT_DIR}/*.ttf ~/.local/share/fonts/")
    print(f"  fc-cache -fv ~/.local/share/fonts/")
    print(f"\nThen set in your editor:")
    print(f'  "editor.fontFamily": "\'Mentl Mono\', monospace"')
    print(f'  "editor.fontLigatures": true')
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
