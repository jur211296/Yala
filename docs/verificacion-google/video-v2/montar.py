"""Monta el video de verificación: tramos del iPhone con rótulo a la derecha + tarjetas a pantalla completa.

Uso: python montar.py plan.json salida.mp4
plan.json: {"raw": "raw.mp4", "items": [
  {"type": "card", "title": "...", "body": ["...", "..."], "secs": 8},
  {"type": "clip", "start": 3.0, "end": 9.5, "title": "...", "body": ["..."], "speed": 1.0}
]}
"""
import json, os, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont

W, H = 1920, 1080
BG = (14, 14, 28)
FG = (240, 240, 250)
MUTED = (170, 172, 200)
ACCENT = (124, 120, 255)
FONT = "/System/Library/Fonts/HelveticaNeue.ttc"


def font(size, bold=False):
    return ImageFont.truetype(FONT, size, index=1 if bold else 0)


def wrap(draw, text, f, width):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if draw.textlength(t, font=f) <= width:
            cur = t
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def draw_text_block(draw, x, y, width, title, body, tsize=46, bsize=32, step=None):
    if step:
        draw.text((x, y), step, font=font(26, True), fill=ACCENT)
        y += 48
    for line in wrap(draw, title, font(tsize, True), width):
        draw.text((x, y), line, font=font(tsize, True), fill=FG)
        y += int(tsize * 1.25)
    y += 24
    for para in body:
        bullet = para.startswith("• ")
        indent = 30 if bullet else 0
        lines = wrap(draw, para[2:] if bullet else para, font(bsize), width - indent)
        for i, line in enumerate(lines):
            if bullet and i == 0:
                draw.text((x, y), "•", font=font(bsize, True), fill=ACCENT)
            draw.text((x + indent, y), line, font=font(bsize), fill=FG if not para.startswith("(") else MUTED)
            y += int(bsize * 1.35)
        y += 14
    return y


def card_png(path, item):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    draw_text_block(d, 160, 140, W - 320, item["title"], item.get("body", []), 58, 34, item.get("step"))
    d.text((160, H - 80), "Yala · OAuth verification demo · project yala-502622", font=font(24), fill=MUTED)
    img.save(path)


def panel_png(path, item):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    draw_text_block(d, 760, 120, W - 760 - 100, item["title"], item.get("body", []), 44, 30, item.get("step"))
    d.text((760, H - 70), "Yala · OAuth verification demo · project yala-502622", font=font(22), fill=MUTED)
    img.save(path)


def run(cmd):
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def main():
    plan = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    raw = plan["raw"]
    tmp = tempfile.mkdtemp(prefix="montar-", dir=os.path.dirname(os.path.abspath(out)))
    parts = []
    for i, it in enumerate(plan["items"]):
        png = os.path.join(tmp, f"{i:02d}.png")
        mp4 = os.path.join(tmp, f"{i:02d}.mp4")
        if it["type"] == "card":
            card_png(png, it)
            run(["ffmpeg", "-y", "-loop", "1", "-i", png, "-t", str(it["secs"]), "-r", "30",
                 "-c:v", "libx264", "-pix_fmt", "yuv420p", mp4])
        else:
            panel_png(png, it)
            speed = it.get("speed", 1.0)
            dur = (it["end"] - it["start"]) / speed
            hold = it.get("hold", 0)
            vf = (f"[0:v]trim={it['start']}:{it['end']},setpts=(PTS-STARTPTS)/{speed},fps=30,"
                  f"scale=-2:1000,tpad=stop_mode=clone:stop_duration={hold}[ph];"
                  f"[1:v][ph]overlay=x=150:y=40[v]")
            run(["ffmpeg", "-y", "-i", raw, "-loop", "1", "-t", str(dur + hold), "-i", png,
                 "-filter_complex", vf, "-map", "[v]", "-t", str(dur + hold), "-r", "30",
                 "-c:v", "libx264", "-pix_fmt", "yuv420p", mp4])
        parts.append(mp4)
    lst = os.path.join(tmp, "list.txt")
    with open(lst, "w") as f:
        for p in parts:
            f.write(f"file '{p}'\n")
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", "-movflags", "+faststart", out])
    print(out)


if __name__ == "__main__":
    main()
