"""Generate platform icon sizes from Rebecca's single approved artwork."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
image = Image.open(root / 'assets/images/rebecca.png').convert('RGBA')
def save(path, size):
    path.parent.mkdir(parents=True, exist_ok=True)
    resized = image.resize(size, Image.Resampling.LANCZOS)
    if path.suffix.lower() == '.webp':
        resized.save(path, lossless=True)
    elif path.suffix.lower() == '.ico':
        resized.save(path, sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])
    else:
        resized.save(path, optimize=True)
res = root / 'android/app/src/main/res'
for density, size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    for name in ['ic_launcher.webp','ic_launcher_round.webp']:
        save(res / f'mipmap-{density}' / name, (size,size))
for path in res.glob('drawable*/splash.png'):
    save(path, (192,192))
for path in res.glob('drawable*/background.png'):
    Image.new('RGB', (1,1), 'black').save(path)
for name in ['ic_launcher_foreground','android12splash']:
    save(res / 'drawable' / f'{name}_rebecca.png', (432,432))
    (res / 'drawable' / f'{name}.xml').write_text(
        '<bitmap xmlns:android="http://schemas.android.com/apk/res/android" '
        f'android:src="@drawable/{name}_rebecca" android:gravity="fill" />\n')
for name in ['ic_launcher_splash.png','ic_launcher_foreground.png','ic_launcher_border.png']:
    save(root / 'assets/images/source' / name, (512,512))
for path in (root / 'assets/images').glob('tray_icon*'):
    if path.suffix in ['.png','.ico']:
        save(path, (256,256))
for folder in [root/'ios/Runner/Assets.xcassets/AppIcon.appiconset', root/'macos/Runner/Assets.xcassets/AppIcon.appiconset']:
    for path in folder.glob('*.png'):
        with Image.open(path) as current:
            size = current.size
        save(path, size)
save(root / 'windows/runner/resources/app_icon.ico', (256,256))
for path in res.glob('values*/styles.xml'):
    text = path.read_text().replace('#ffffff','#000000').replace('#FFFFFF','#000000')
    path.write_text(text)
p = res/'values/colors.xml'
if p.exists():
    import re
    p.write_text(re.sub(r'(<color name="ic_launcher_background">).*?(</color>)',r'\g<1>#000000\2',p.read_text()))
