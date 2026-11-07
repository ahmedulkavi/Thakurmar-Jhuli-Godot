"""Slice and align the generated source art. Requires Pillow for regeneration only."""
from pathlib import Path
from PIL import Image, ImageFilter

assets = Path(__file__).resolve().parent.parent / 'assets'
source = assets / 'source'
sheet = Image.open(source / 'prince-sheet.png').convert('RGBA')
width, height = sheet.size
result = Image.new('RGBA', (160 * 14, 160))
for i in range(14):
    x, y = i % 4, i // 4
    frame = sheet.crop((x * width // 4, y * height // 4, (x + 1) * width // 4, (y + 1) * height // 4))
    alpha = frame.getchannel('A').point(lambda a: 0 if a < 100 else a).filter(ImageFilter.MedianFilter(3))
    frame.putalpha(alpha)
    bbox = alpha.point(lambda a: 255 if a >= 200 else 0).getbbox()
    frame = frame.crop(bbox)
    frame.thumbnail((145, 130), Image.Resampling.LANCZOS)
    result.alpha_composite(frame, (i * 160 + (160 - frame.width) // 2, 151 - frame.height))
result.save(assets / 'prince-frames.png')

objects = Image.open(source / 'forest-objects.png').convert('RGBA')
for name, bounds in {
    'log': (0, 470, 475, 724),
    'rocks': (475, 470, 930, 724),
    'root': (945, 470, 1455, 724),
    'banyan': (1400, 0, 2172, 724),
}.items():
    image = objects.crop(bounds)
    alpha = image.getchannel('A').point(lambda a: 0 if a < 30 else a)
    image.putalpha(alpha)
    image = image.crop(alpha.getbbox())
    image.save(assets / (name + '.png'))

ground = Image.open(source / 'ground.png').convert('RGBA')
ground_mask = ground.getchannel('A').point(lambda a: 255 if a > 100 else 0)
ground.crop(ground_mask.getbbox()).save(assets / 'ground.png')
