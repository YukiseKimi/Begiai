#!/usr/bin/env python3
"""Draws the App Store slides from slides.json.

    Store/Screenshots/compose.py <run> [--shots <folder>] [<slide or device>...]

<folder> holds the raw shots as slides.json names them (iPhone/01-map.png); it is the
approved folder by default, or a run's own shots (runs/<run>/shots) for a draft. The slides
go to runs/<run>/<Device>/<slide>.png, with the framed devices and the specs in
runs/<run>/scratch. It never writes into the approved folder. Each slide is marked new,
same or changed against approved/<Device>/<slide>.png.
"""
import json
import os
import shutil
import struct
import subprocess
import sys
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
APPROVED = HERE / "approved"


def fail(message):
    print(f"compose: {message}", file=sys.stderr)
    sys.exit(1)


def png_info(path):
    """Width, height and PNG color type, from the IHDR chunk."""
    with open(path, "rb") as file:
        head = file.read(33)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"{path} is not a PNG")
    width, height = struct.unpack(">II", head[16:24])
    return width, height, head[25]


def pixels(path):
    """The decoded pixel bytes, to compare two slides; ffmpeg gives rgb24."""
    out = subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-i", str(path), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        capture_output=True, check=True)
    return zlib.crc32(out.stdout)


def callout(size, bezel_size, caption, font_share):
    """The callout layout: the device fits 0.78 H by 0.86 W, its foot at 0.97 H; the header's
    box is 0.12 H high, from 0.06 W and 0.88 W wide, 0.03 H above the device."""
    width, height = size
    bezel_width, bezel_height = bezel_size
    scale = min(0.78 * height / bezel_height, 0.86 * width / bezel_width)
    device_width, device_height = bezel_width * scale, bezel_height * scale
    device = [(width - device_width) / 2, 0.97 * height - device_height, device_width, device_height]
    box_height = 0.12 * height
    box = [0.06 * width, device[1] - 0.03 * height - box_height, 0.88 * width, box_height]
    return device, {"text": caption, "box": box, "fontSize": round(font_share * height, 1)}


def main():
    args = sys.argv[1:]
    if not args or args[0].startswith("-"):
        fail(__doc__.strip())
    run = args.pop(0)
    shots = APPROVED
    slides_file = HERE / "slides.json"
    words = []
    while args:
        word = args.pop(0)
        if word == "--shots":
            shots = Path(args.pop(0)).resolve()
        elif word == "--slides":
            slides_file = Path(args.pop(0)).resolve()
        else:
            words.append(word)
    spec = json.loads(slides_file.read_text())
    look, devices, slides = spec["look"], spec["devices"], spec["slides"]
    for name in spec["order"]:
        if name not in slides:
            fail(f"order names {name}, which is not a slide")
    for word in words:
        if word not in slides and word not in devices:
            fail(f"{word} is neither a slide nor a device")
    wanted_slides = [w for w in words if w in slides] or spec["order"]
    wanted_devices = [w for w in words if w in devices] or list(devices)

    # Check every shot and bezel before anything draws.
    for name in wanted_slides:
        slide = slides[name]
        if slide["layout"] != "callout":
            fail(f"{name}: only the callout layout is drawn here")
        for device, entries in slide["shots"].items():
            if device not in wanted_devices:
                continue
            if len(entries) != 1:
                fail(f"{name}: a callout shows one shot on {device}")
            entry = entries[0]
            if not (shots / entry["shot"]).is_file():
                fail(f"{name}: no shot {shots / entry['shot']}")
            bezel = devices[device]["bezels"].get(entry["bezel"])
            if not bezel or not Path(os.path.expanduser(bezel)).is_file():
                fail(f"{name}: {device} has no {entry['bezel']} bezel at {bezel}")

    out = HERE / "runs" / run
    scratch = out / "scratch"
    for device in wanted_devices:
        shutil.rmtree(out / device, ignore_errors=True)
    scratch.mkdir(parents=True, exist_ok=True)
    draw = scratch / "draw"
    subprocess.run(["xcrun", "swiftc", "-Onone", str(HERE / "Draw.swift"), "-o", str(draw)], check=True)

    counts = {"new": 0, "same": 0, "changed": 0}
    order = {name: index for index, name in enumerate(spec["order"])}
    for name in sorted(wanted_slides, key=lambda n: order.get(n, 99)):
        slide = slides[name]
        for device, entries in slide["shots"].items():
            if device not in wanted_devices:
                continue
            setup = devices[device]
            size = setup["size"]
            entry = entries[0]
            bezel = Path(os.path.expanduser(setup["bezels"][entry["bezel"]]))
            framed = scratch / f"{device}-{name}-framed.png"
            subprocess.run([str(draw), "frame", str(bezel), str(shots / entry["shot"]), str(framed)], check=True)
            if setup.get("trim"):
                # Cut the bezel's clear margins, so the device's size is its opaque box.
                trimmed = scratch / f"{device}-{name}-trimmed.png"
                trimmed.unlink(missing_ok=True)
                box = subprocess.run(
                    ["python3", "-I", str(Path.home() / ".claude/skills/app-store-story-slides/scripts/bezel_box.py"),
                     str(framed), "--cut", str(trimmed)], capture_output=True, text=True)
                if box.returncode != 0:
                    fail(f"bezel_box: {box.stdout}{box.stderr}")
                framed = trimmed
            framed_width, framed_height, _ = png_info(framed)
            font = entry.get("captionFont", setup.get("captionFont", 1 / 28))
            rect, caption = callout(size, (framed_width, framed_height), entry["caption"], font)
            slide_spec = {"size": size, "background": look["background"], "text": look["text"],
                          "devices": [{"image": str(framed), "rect": rect}], "captions": [caption], "cutouts": []}
            spec_path = scratch / f"{device}-{name}.json"
            spec_path.write_text(json.dumps(slide_spec, indent=2))
            target = out / device / f"{name}.png"
            target.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run([str(draw), "slide", str(spec_path), str(target)], check=True)
            width, height, color_type = png_info(target)
            if [width, height] != size or color_type != 2:
                fail(f"{target} is {width} × {height}, color type {color_type}: not {size[0]} × {size[1]} RGB")
            approved = APPROVED / device / f"{name}.png"
            state = "new" if not approved.is_file() else ("same" if pixels(approved) == pixels(target) else "changed")
            counts[state] += 1
            print(f"{state:8} {device}/{name}.png")
    print(f"{counts['new']} new · {counts['same']} same · {counts['changed']} changed · {out}")


if __name__ == "__main__":
    main()
