#!/usr/bin/env python3
"""Generate App/Resources/Assets.xcassets (colour sets with light/dark variants and the app icon).

Usage: python3 -I tools/make_assets.py   (needs Pillow for the icon: pip install pillow)

The colour table below is the single source of truth for the design tokens in
docs/02-architecture.md §2.7; edit it here and regenerate.
"""
from __future__ import annotations

import json
from pathlib import Path

ASSETS = Path("App/Resources/Assets.xcassets")

# name: (light, dark)
COLORS: dict[str, tuple[str, str]] = {
    "Bg": ("F9F4EE", "15130F"),
    "Surface": ("FFFFFF", "211E1A"),
    "SurfaceMuted": ("F1E8DF", "2C2823"),
    "Border": ("E8DFD5", "38332D"),
    "TextPrimary": ("1E1A16", "F3EEE8"),
    "TextSecondary": ("8B8279", "A59D94"),
    "Accent": ("4746B4", "7C7BF0"),
    "AccentGradientTop": ("5B59D8", "8E8DF5"),
    "Badge": ("F0522F", "FF6A4A"),
    "Success": ("3E9B6E", "5BC08E"),
    "Warning": ("D9912B", "E8A84A"),
    "LevelA1": ("4F9D78", "6DBE97"),
    "LevelA2": ("3E9A9F", "5DBBC0"),
    "LevelB1": ("4F7FC4", "72A0E3"),
    "LevelB2": ("6A63C9", "8C86E8"),
    "LevelC1": ("9A5BB5", "BB7DD6"),
}

INFO = {"author": "xcode", "version": 1}


def components(hex_value: str) -> dict[str, str]:
    r, g, b = (int(hex_value[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return {"red": f"{r:.3f}", "green": f"{g:.3f}", "blue": f"{b:.3f}", "alpha": "1.000"}


def color_entry(hex_value: str, dark: bool) -> dict:
    entry: dict = {
        "idiom": "universal",
        "color": {"color-space": "srgb", "components": components(hex_value)},
    }
    if dark:
        entry["appearances"] = [{"appearance": "luminosity", "value": "dark"}]
    return entry


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def write_colors() -> None:
    write_json(ASSETS / "Contents.json", {"info": INFO})
    names = dict(COLORS)
    names["AccentColor"] = COLORS["Accent"]  # the app-wide tint
    for name, (light, dark) in names.items():
        write_json(
            ASSETS / f"{name}.colorset" / "Contents.json",
            {"colors": [color_entry(light, False), color_entry(dark, True)], "info": INFO},
        )


def write_icon() -> None:
    from PIL import Image, ImageDraw, ImageFont

    size = 1024
    top = tuple(int(COLORS["AccentGradientTop"][0][i:i + 2], 16) for i in (0, 2, 4))
    bottom = tuple(int(COLORS["Accent"][0][i:i + 2], 16) for i in (0, 2, 4))
    image = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(image)
    for y in range(size):
        t = y / (size - 1)
        draw.line([(0, y), (size, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))

    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf", 520)
    text = "Aa"
    box = draw.textbbox((0, 0), text, font=font)
    x = (size - (box[2] - box[0])) / 2 - box[0]
    y = (size - (box[3] - box[1])) / 2 - box[1] - 20
    draw.text((x, y), text, font=font, fill=(255, 255, 255))

    folder = ASSETS / "AppIcon.appiconset"
    folder.mkdir(parents=True, exist_ok=True)
    image.save(folder / "icon-1024.png")
    write_json(
        folder / "Contents.json",
        {
            "images": [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
            "info": INFO,
        },
    )


if __name__ == "__main__":
    write_colors()
    write_icon()
    print(f"wrote {len(COLORS) + 1} colour sets and the app icon to {ASSETS}")
