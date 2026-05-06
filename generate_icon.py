"""
Generates the LikeALocal app launcher icon:
- Orange-to-pink gradient background (matching top bar gradient)
- Two white rounded squares stacked (matching Icons.layers_rounded)
Outputs all Android mipmap sizes.
"""
from PIL import Image, ImageDraw
import math, os

def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))

def make_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # --- Rounded-rect background helper ---
    def draw_rounded_rect(draw, xy, radius, fill):
        x0, y0, x1, y1 = xy
        draw.rectangle([x0 + radius, y0, x1 - radius, y1], fill=fill)
        draw.rectangle([x0, y0 + radius, x1, y1 - radius], fill=fill)
        draw.ellipse([x0, y0, x0 + 2*radius, y0 + 2*radius], fill=fill)
        draw.ellipse([x1 - 2*radius, y0, x1, y0 + 2*radius], fill=fill)
        draw.ellipse([x0, y1 - 2*radius, x0 + 2*radius, y1], fill=fill)
        draw.ellipse([x1 - 2*radius, y1 - 2*radius, x1, y1], fill=fill)

    # --- Gradient background (orange → pink, top-left to bottom-right) ---
    c1 = (232, 88, 10)   # kOrange  #E8580A
    c2 = (255, 107, 157) # pink     #FF6B9D
    bg_radius = int(size * 0.22)

    # Draw gradient pixel by pixel via horizontal bands (fast enough for icon sizes)
    for y in range(size):
        t = y / (size - 1)
        color = lerp_color(c1, c2, t)
        draw.line([(0, y), (size - 1, y)], fill=color + (255,))

    # Clip to rounded rect by compositing
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    draw_rounded_rect(mask_draw, [0, 0, size - 1, size - 1], bg_radius, 255)
    img.putalpha(mask)

    # --- Two white stacked squares (layers icon) ---
    square_w = int(size * 0.48)
    square_h = int(size * 0.33)
    sq_radius = int(size * 0.06)
    gap = int(size * 0.055)
    shadow_alpha = 60

    # Centre of icon
    cx, cy = size // 2, size // 2

    total_h = square_h * 2 + gap
    top_y = cy - total_h // 2

    for idx in range(2):
        y0 = top_y + idx * (square_h + gap)
        y1 = y0 + square_h
        x0 = cx - square_w // 2
        x1 = cx + square_w // 2

        # Subtle drop shadow
        sd = int(size * 0.025)
        shadow_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        sd_draw = ImageDraw.Draw(shadow_layer)
        draw_rounded_rect(sd_draw, [x0 + sd, y0 + sd, x1 + sd, y1 + sd],
                          sq_radius, (0, 0, 0, shadow_alpha))
        img = Image.alpha_composite(img, shadow_layer)

        # White square
        sq_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        sq_draw = ImageDraw.Draw(sq_layer)
        draw_rounded_rect(sq_draw, [x0, y0, x1, y1], sq_radius, (255, 255, 255, 255))
        img = Image.alpha_composite(img, sq_layer)

    return img

# Android mipmap sizes
sizes = {
    "mdpi":    48,
    "hdpi":    72,
    "xhdpi":   96,
    "xxhdpi":  144,
    "xxxhdpi": 192,
}

base = os.path.join(os.path.dirname(__file__),
                    "android", "app", "src", "main", "res")

for density, px in sizes.items():
    icon = make_icon(px)
    out_dir = os.path.join(base, f"mipmap-{density}")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "ic_launcher.png")
    icon.save(path, "PNG")
    print(f"  saved {density:10s} ({px}x{px}) → {path}")

# Also save a 1024 preview
preview = make_icon(1024)
preview_path = os.path.join(os.path.dirname(__file__), "icon_preview_1024.png")
preview.save(preview_path, "PNG")
print(f"\n  preview saved → {preview_path}")
print("Done.")
