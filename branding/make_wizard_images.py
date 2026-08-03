"""Generate the PW Docs Inno Setup wizard images.

Run:  python branding/make_wizard_images.py

Writes straight into desktop-apps/package/inno/res/, replacing the upstream
ONLYOFFICE-branded artwork. Inno picks the variant matching the user's DPI
from the wildcard in common.iss (WizImage-Light-*.png), so every size in the
upstream set has to exist or high-DPI installs fall back to a blurry upscale.
"""
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.abspath(os.path.join(HERE, "..", "desktop-apps", "package", "inno", "res"))

DOC_BLUE = (41, 105, 176)
WIZ_SIZES = [(164, 314), (202, 386), (240, 459), (290, 556),
             (315, 604), (366, 700), (416, 797)]
SMALL_SIZES = [58, 71, 85, 103, 112, 129, 147]

THEMES = {
    "Light": dict(bg=(255, 255, 255), text=(45, 52, 64), sub=(120, 130, 145),
                  blobs=[(226, 238, 250), (232, 244, 236), (250, 236, 230)]),
    "Dark":  dict(bg=(32, 36, 43), text=(236, 240, 246), sub=(150, 160, 175),
                  blobs=[(44, 58, 78), (42, 58, 50), (66, 50, 44)]),
}


def _font(px, bold=True):
    names = ("segoeuib.ttf", "arialbd.ttf") if bold else ("segoeui.ttf", "arial.ttf")
    for n in names:
        try:
            return ImageFont.truetype(n, px)
        except OSError:
            continue
    return ImageFont.load_default()


_MARK_CACHE = {}


def doc_mark(size, theme="Light"):
    """The PW monogram, drawn at `size` px square on transparency.

    Sourced from branding/logo/, produced by make_logo.py from the supplied
    artwork. The mark is solid black, so the dark wizard variant uses the
    white recolour - otherwise it disappears into the panel.
    """
    key = (size, theme)
    if key in _MARK_CACHE:
        return _MARK_CACHE[key]

    name = "pw-mark-white.png" if theme == "Dark" else "pw-mark-black.png"
    path = os.path.join(HERE, "logo", name)
    if not os.path.isfile(path):
        raise SystemExit("missing %s - run make_logo.py first" % path)

    img = Image.open(path).convert("RGBA").resize((size, size), Image.LANCZOS)
    _MARK_CACHE[key] = img
    return img


def wiz_image(w, h, theme):
    t = THEMES[theme]
    img = Image.new("RGB", (w, h), t["bg"])
    d = ImageDraw.Draw(img)

    # Soft corner shapes, echoing the upstream layout without its brand colours.
    d.pieslice([-w * 0.55, -h * 0.30, w * 0.60, h * 0.36], 0, 360, fill=t["blobs"][0])
    d.pieslice([-w * 0.35, h * 0.62, w * 0.75, h * 1.35], 0, 360, fill=t["blobs"][1])
    d.pieslice([w * 0.45, -h * 0.16, w * 1.50, h * 0.30], 0, 360, fill=t["blobs"][2])

    mark = max(28, int(w * 0.30))
    m = doc_mark(mark, theme)
    img.paste(m, ((w - mark) // 2, int(h * 0.38) - mark // 2), m)

    f_title = _font(max(11, int(w * 0.115)), bold=True)
    f_sub = _font(max(8, int(w * 0.070)), bold=False)

    y = int(h * 0.38) + mark // 2 + int(h * 0.045)
    for text, font, fill in (("PW Docs", f_title, t["text"]),
                             ("Document Editor", f_sub, t["sub"])):
        bb = d.textbbox((0, 0), text, font=font)
        d.text(((w - (bb[2] - bb[0])) / 2 - bb[0], y), text, font=font, fill=fill)
        y += (bb[3] - bb[1]) + int(h * 0.028)
    return img


def small_image(s, theme):
    t = THEMES[theme]
    img = Image.new("RGB", (s, s), t["bg"])
    mark = int(s * 0.72)
    m = doc_mark(mark, theme)
    img.paste(m, ((s - mark) // 2, (s - mark) // 2), m)
    return img


if not os.path.isdir(RES):
    raise SystemExit("res dir not found: %s" % RES)

count = 0
for theme in THEMES:
    for w, h in WIZ_SIZES:
        wiz_image(w, h, theme).save(
            os.path.join(RES, "WizImage-%s-%dx%d.png" % (theme, w, h)))
        count += 1
    for s in SMALL_SIZES:
        small_image(s, theme).save(
            os.path.join(RES, "WizSmallImage-%s-%dx%d.png" % (theme, s, s)))
        count += 1

print("Wrote %d wizard images to %s" % (count, RES))
