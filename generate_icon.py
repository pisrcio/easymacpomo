#!/usr/bin/env python3
"""Generate a red tomato app icon matching the menu bar icon style."""

import struct
import io
from PIL import Image, ImageDraw

def draw_tomato(size):
    """Draw a red tomato icon at the given size."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Padding proportional to size
    pad = size // 8
    body_rect = [pad, pad + size // 12, size - pad, size - pad]

    # Red tomato body (circle)
    draw.ellipse(body_rect, fill=(220, 50, 50, 255))

    # Subtle highlight on upper left
    highlight_size = size // 5
    hx = pad + size // 5
    hy = pad + size // 4
    highlight_rect = [hx, hy, hx + highlight_size, hy + highlight_size]
    draw.ellipse(highlight_rect, fill=(255, 120, 120, 60))

    # Green stem
    stem_width = max(2, size // 12)
    cx = size // 2
    top = body_rect[1]
    stem_top = top - size // 10
    draw.line([(cx, top), (cx, stem_top)], fill=(60, 140, 50, 220), width=stem_width)

    # Small leaf to the right
    leaf_w = size // 5
    leaf_h = size // 8
    leaf_x = cx + 1
    leaf_y = stem_top + size // 20

    # Draw leaf as an ellipse rotated slightly
    leaf_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    leaf_draw = ImageDraw.Draw(leaf_img)
    leaf_draw.ellipse(
        [leaf_x, leaf_y, leaf_x + leaf_w, leaf_y + leaf_h],
        fill=(60, 160, 50, 200),
    )
    leaf_img = leaf_img.rotate(-20, center=(leaf_x + leaf_w // 2, leaf_y + leaf_h // 2))
    img = Image.alpha_composite(img, leaf_img)

    return img


def create_icns(images, output_path):
    """Create a .icns file from a dict of {size: Image}."""
    # icns type codes for sizes
    type_map = {
        16: b"icp4",    # 16x16
        32: b"icp5",    # 32x32
        64: b"icp6",    # 64x64
        128: b"ic07",   # 128x128
        256: b"ic08",   # 256x256
        512: b"ic09",   # 512x512
        1024: b"ic10",  # 1024x1024
    }

    entries = []
    for sz, icon_type in sorted(type_map.items()):
        if sz in images:
            buf = io.BytesIO()
            images[sz].save(buf, format="PNG")
            png_data = buf.getvalue()
            # Each entry: type(4) + length(4) + data
            entry_len = 8 + len(png_data)
            entries.append(struct.pack(">4sI", icon_type, entry_len) + png_data)

    body = b"".join(entries)
    total_len = 8 + len(body)
    header = struct.pack(">4sI", b"icns", total_len)

    with open(output_path, "wb") as f:
        f.write(header + body)


def main():
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    images = {}
    for s in sizes:
        images[s] = draw_tomato(s)

    # Save .icns
    create_icns(images, "AppIcon.icns")

    # Also save a 512px PNG for reference
    images[512].save("AppIcon.png")

    print("Generated AppIcon.icns and AppIcon.png")


if __name__ == "__main__":
    main()
