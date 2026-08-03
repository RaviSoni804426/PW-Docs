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


def doc_mark(size):
    """The PW Docs page mark, drawn at `size` px square on transparency."""
    s = size
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = max(1, s // 16)
    d.rounded_rectangle([pad, pad, s - pad, s - pad], radius=max(2, s // 8), fill=DOC_BLUE)

    m = max(2, s // 5)
    fold = max(2, s // 6)
    left, right, top, bottom = m, s - m, m, s - m
    d.polygon([(left, top), (right - fold, top), (right, top + fold),
               (right, bottom), (left, bottom)], fill=(255, 255, 255, 245))
    d.polygon([(right - fold, top), (right - fold, top + fold), (right, top + fold)],
              fill=(214, 224, 236, 245))

    if s >= 32:
        pad_x = max(1, (right - left) // 6)
        x0, x1 = left + pad_x, right - pad_x
        y = top + fold + max(1, s // 14)
        gap = max(2, s // 10)
        thick = max(1, s // 32)
        n = 4 if s >= 64 else 3
        for i in range(n):
            if y + thick > bottom - max(1, s // 12):
                break
            xr = x1 if i < n - 1 else x0 + (x1 - x0) * 0.55
            d.rectangle([x0, y, xr, y + thick], fill=DOC_BLUE)
            y += gap
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
    m = doc_mark(mark)
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
    m = doc_mark(mark)
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
