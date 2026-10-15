"""Genera l'icona di Antigram: la facciata di un palazzone grigio, una sola finestra accesa."""
import random
import sys
from PIL import Image, ImageDraw

S = 1024
out = sys.argv[1]
img = Image.new("RGB", (S, S), (30, 29, 28))
d = ImageDraw.Draw(img)

# Cielo piatto e palazzo
d.rectangle([0, 0, S, S], fill=(58, 57, 55))
left, top, right = 150, 170, 874
d.rectangle([left, top, right, S], fill=(124, 122, 116))
d.rectangle([left, top, right, top + 34], fill=(98, 96, 91))

# Pannelli prefabbricati e finestre
cols, rows = 5, 6
gx, gy = (right - left) / cols, (S - top - 34) / rows
random.seed(7)
for r in range(rows):
    for c in range(cols):
        x0 = left + c * gx
        y0 = top + 34 + r * gy
        d.rectangle([x0, y0, x0 + gx, y0 + gy], outline=(104, 102, 97), width=4)
        wx0, wy0 = x0 + gx * 0.24, y0 + gy * 0.22
        wx1, wy1 = x0 + gx * 0.76, y0 + gy * 0.70
        lit = (r, c) == (3, 3)
        d.rectangle([wx0, wy0, wx1, wy1], fill=(206, 204, 196) if lit else (44, 43, 41))
        d.line([(wx0 + wx1) / 2, wy0, (wx0 + wx1) / 2, wy1], fill=(104, 102, 97) if lit else (70, 69, 66), width=5)

img.save(out)
