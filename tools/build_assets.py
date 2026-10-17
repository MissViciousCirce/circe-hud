"""Generate Circe HUD's original pointer; no downloaded or game imagery."""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
output = root / "CirceHUD" / "Assets"
output.mkdir(parents=True, exist_ok=True)
scale = 4
image = Image.new("RGBA", (64 * scale, 64 * scale))
draw = ImageDraw.Draw(image)
outline = [(32, 4), (55, 55), (32, 44), (9, 55)]
inner = [(32, 11), (49, 49), (32, 40), (15, 49)]
draw.polygon([(x * scale, y * scale) for x, y in outline], fill=(3, 22, 28, 240))
draw.polygon([(x * scale, y * scale) for x, y in inner], fill=(67, 236, 248, 255))
image.resize((64, 64), Image.Resampling.LANCZOS).save(output / "pointer.png.lua", format="PNG")
print("Generated original antialiased pointer")
