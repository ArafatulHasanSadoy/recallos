#!/usr/bin/env python3
"""Rebuild RecallOS branding. Requires Python 3 and ImageMagick (`magick`).

One geometry produces the Flutter painter, SVGs, Android vectors and PNGs.
Run from anywhere: python3 tool/brand/generate.py
"""
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
BRAND = ROOT / 'assets/brand'
RES = ROOT / 'android/app/src/main/res'
IOS = ROOT / 'ios/Runner/Assets.xcassets'
INK, PAPER, OCHRE = '#1F1B13', '#F0EADC', '#C8901A'
# The R and its counter are true cutouts, so the mark works on any surface.
BODY = ('M10 12 L42 12 L60 30 L60 46 Q60 52 54 52 L10 52 '
        'Q4 52 4 46 L4 18 Q4 12 10 12 Z '
        'M18 22 L29 22 Q39 22 39 30 Q39 35 34 37 L42 46 '
        'L33 46 L26 38 L25 38 L25 46 L18 46 Z '
        'M25 28 L25 32 L29 32 Q32 32 32 30 Q32 28 29 28 Z')
FOLD = 'M42 12 L60 30 L47 30 Q42 30 42 25 Z'


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def shapes(ink=INK, ochre=OCHRE):
    return (f'<path fill="{ink}" fill-rule="evenodd" d="{BODY}"/>'
            f'<path fill="{ochre}" d="{FOLD}"/>')


def svg(content, size=64):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" '
            f'height="{size}" viewBox="0 0 64 64" role="img" '
            f'aria-label="RecallOS"><title>RecallOS</title>{content}</svg>\n')


def render(source, target, size, opaque=False):
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temp:
        src = Path(temp) / 'source.svg'
        # Render at twice the output size before downsampling, even for the
        # 64-unit SVG marks. This keeps large transparent exports smooth.
        source = re.sub(r'width="[0-9]+" height="[0-9]+"',
                        f'width="{size}" height="{size}"', source, count=1)
        src.write_text(source)
        subprocess.run(['magick', '-background', 'none', '-density', '144',
                        str(src), '-resize', f'{size}x{size}',
                        '-strip', ('PNG24:' if opaque else 'PNG32:') + str(target)],
                       check=True)


def vector(ink, ochre, size=108, inset=24, scale=0.9375):
    # 60 / 108 viewport: all artwork stays inside the adaptive safe circle.
    return f'''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="{size}dp" android:height="{size}dp"
    android:viewportWidth="{size}" android:viewportHeight="{size}">
    <group android:translateX="{inset}" android:translateY="{inset}"
        android:scaleX="{scale}" android:scaleY="{scale}">
        <path android:fillColor="{ink}" android:fillType="evenOdd" android:pathData="{BODY}"/>
        <path android:fillColor="{ochre}" android:pathData="{FOLD}"/>
    </group>
</vector>
'''


def dart_path(data):
    methods = {'M': 'moveTo', 'L': 'lineTo', 'Q': 'quadraticBezierTo'}
    result = ['Path()..fillType = PathFillType.evenOdd']
    for command, args in re.findall(r'([MLQZ])([0-9 .-]*)', data):
        result.append('..close()' if command == 'Z' else
                      f'..{methods[command]}({", ".join(args.split())})')
    return '\n    '.join(result)


def main():
    mark = svg(shapes())
    inverse = svg(shapes(PAPER, '#D8A31A'))
    icon = svg(f'<rect width="64" height="64" fill="{INK}"/>'
               f'<g transform="translate(9.6 9.6) scale(.7)">{shapes(PAPER)}</g>', 1024)
    write(BRAND / 'recallos-mark.svg', mark)
    write(BRAND / 'recallos-mark-inverse.svg', inverse)
    write(BRAND / 'recallos-appicon.svg', icon)
    # Editable wordmark; the app uses its bundled Archivo font directly.
    write(BRAND / 'recallos-lockup.svg',
          '<svg xmlns="http://www.w3.org/2000/svg" width="360" height="64" '
          'viewBox="0 0 360 64" role="img" aria-label="RecallOS">'
          + shapes() + f'<text x="80" y="41" fill="{INK}" '
          'font-family="Archivo, sans-serif" font-weight="700" '
          'font-size="26" letter-spacing="4">RECALLOS</text></svg>\n')
    for size in (1024, 512, 192, 180, 120, 48):
        render(icon, BRAND / f'png/appicon-{size}.png', size, opaque=True)
    rounded = svg('<defs><clipPath id="rounded"><rect width="64" height="64" '
                  'rx="14"/></clipPath></defs><g clip-path="url(#rounded)">'
                  f'<rect width="64" height="64" fill="{INK}"/>'
                  f'<g transform="translate(9.6 9.6) scale(.7)">{shapes(PAPER)}</g></g>')
    render(rounded, BRAND / 'png/appicon-1024-rounded.png', 1024)
    for name, source in [('light', mark), ('dark', inverse)]:
        for size in (512, 256, 96):
            render(source, BRAND / f'png/mark-{name}-{size}.png', size)
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                          ('xxhdpi', 144), ('xxxhdpi', 192)]:
        render(icon, RES / f'mipmap-{density}/ic_launcher.png', size, opaque=True)
    write(RES / 'drawable/ic_launcher_foreground.xml', vector(PAPER, OCHRE))
    write(RES / 'drawable/ic_launcher_monochrome.xml', vector('#FFFFFF', '#FFFFFF'))
    adaptive = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/brand_icon_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
{monochrome}</adaptive-icon>
'''
    write(RES / 'mipmap-anydpi-v26/ic_launcher.xml', adaptive.format(monochrome=''))
    write(RES / 'mipmap-anydpi-v33/ic_launcher.xml', adaptive.format(
        monochrome='    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>\n'))
    for suffix, page, ink, ochre in [('', '#E4DAC5', INK, OCHRE),
                                    ('-night', '#15130F', PAPER, '#D8A31A')]:
        write(RES / f'values{suffix}/brand_colors.xml', f'''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="brand_page">{page}</color>
    <color name="brand_icon_background">{INK}</color>
</resources>
''')
        write(RES / f'drawable{suffix}/brand_splash.xml',
              vector(ink, ochre, size=288, inset=72, scale=2.25))
        write(RES / f'drawable{suffix}/brand_launch_mark.xml',
              vector(ink, ochre, size=144, inset=0, scale=2.25))
    for folder in ('drawable', 'drawable-v21'):
        write(RES / f'{folder}/launch_background.xml', '''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/brand_page"/>
    <item android:width="144dp" android:height="144dp" android:gravity="center"
        android:drawable="@drawable/brand_launch_mark"/>
</layer-list>
''')
    for suffix, parent in [('', 'Light'), ('-night', 'Black')]:
        for modern in (False, True):
            extra = '''
        <item name="android:windowSplashScreenBackground">@color/brand_page</item>
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/brand_splash</item>
        <item name="android:windowSplashScreenAnimationDuration">0</item>''' if modern else ''
            write(RES / f'values{suffix}{"-v31" if modern else ""}/styles.xml', f'''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.{parent}.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="android:statusBarColor">@color/brand_page</item>
        <item name="android:navigationBarColor">@color/brand_page</item>
        <item name="android:windowLightStatusBar">{str(not suffix).lower()}</item>{extra}
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.{parent}.NoTitleBar">
        <item name="android:windowBackground">@color/brand_page</item>
    </style>
</resources>
''')
    catalog = json.loads((IOS / 'AppIcon.appiconset/Contents.json').read_text())
    for item in catalog['images']:
        size = round(float(item['size'].split('x')[0]) * float(item['scale'][:-1]))
        render(icon, IOS / 'AppIcon.appiconset' / item['filename'], size, opaque=True)
    launch_images = []
    for dark, source in [(False, mark), (True, inverse)]:
        for scale in (1, 2, 3):
            name = f'LaunchImage{"-dark" if dark else ""}{"@" + str(scale) + "x" if scale > 1 else ""}.png'
            render(source, IOS / 'LaunchImage.imageset' / name, 144 * scale)
            item = {'idiom': 'universal', 'filename': name, 'scale': f'{scale}x'}
            if dark:
                item['appearances'] = [{'appearance': 'luminosity', 'value': 'dark'}]
            launch_images.append(item)
    write(IOS / 'LaunchImage.imageset/Contents.json',
          json.dumps({'images': launch_images, 'info': {'version': 1, 'author': 'xcode'}}, indent=2) + '\n')
    colors = []
    for dark, rgb in [(False, (228, 218, 197)), (True, (21, 19, 15))]:
        item = {'idiom': 'universal', 'color': {'color-space': 'srgb', 'components':
                dict(zip(('red', 'green', 'blue', 'alpha'),
                         [f'{value / 255:.6f}' for value in rgb] + ['1.000']))}}
        if dark:
            item['appearances'] = [{'appearance': 'luminosity', 'value': 'dark'}]
        colors.append(item)
    write(IOS / 'BrandBackground.colorset/Contents.json',
          json.dumps({'colors': colors, 'info': {'version': 1, 'author': 'xcode'}}, indent=2) + '\n')
    write(ROOT / 'lib/core/ui/brand_paths.dart', f'''// Generated by tool/brand/generate.py. Edit the generator, then regenerate.
import 'dart:ui';

abstract final class BrandPaths {{
  static Path card() => {dart_path(BODY)};
  static Path fold() => {dart_path(FOLD)};
}}
''')
    print('Generated Flutter paths, SVG masters, PNG exports, Android and iOS branding.')


if __name__ == '__main__':
    main()
