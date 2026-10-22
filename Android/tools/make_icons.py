from PIL import Image, ImageDraw
import os

base = r'E:/AllClear水印天敌/AllClear/android/app/src/main/res'
sizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
for d, s in sizes.items():
    folder = os.path.join(base, 'mipmap-' + d)
    os.makedirs(folder, exist_ok=True)
    img = Image.new('RGBA', (s, s), (48, 114, 246, 255))
    dr = ImageDraw.Draw(img)
    pad = s * 0.16
    w = max(2, int(s * 0.07))
    dr.ellipse([pad, pad, s - pad, s - pad], outline=(255, 255, 255, 255), width=w)
    dr.line([s * 0.3, s * 0.7, s * 0.7, s * 0.3], fill=(255, 255, 255, 255), width=w)
    img.save(os.path.join(folder, 'ic_launcher.png'))
    img.save(os.path.join(folder, 'ic_launcher_round.png'))
    print(folder)
