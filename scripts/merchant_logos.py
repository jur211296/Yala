#!/usr/bin/env python3
"""Banco de comercios y sus logos para los pagos planificados.

La fuente de verdad es `Yala/App/Logic/MerchantLogos/MerchantCatalog.json` (lo lee la app). Este script baja, UNA vez y
en la Mac, el icono que cada comercio publica en su propia web y lo deja empaquetado en
`Yala/App/Logic/MerchantLogos/MerchantLogos.xcassets`. El teléfono no descarga nada: los logos van dentro de la app.

Uso:
    python3 scripts/merchant_logos.py fetch [--only id1,id2] [--force] [--cache DIR]   # baja y empaqueta
    python3 scripts/merchant_logos.py check                              # valida el catálogo

De dónde sale cada logo, por orden: el `apple-touch-icon` o el icono más grande que declara la portada del dominio,
`/apple-touch-icon.png`, y como respaldo los iconos públicos de Google y DuckDuckGo para ese dominio. Se queda el más
grande; por debajo de 64 px no hay logo y la app pinta la inicial sobre color.

Revisión a ojo: tras bajar, se mira la hoja de contactos. Si un logo no es el de la marca (la app de otra empresa, el
escudo genérico del Estado, una imagen vacía), la entrada lleva `"noLogo": true` y el script no lo vuelve a poner.

Reglas de uso de marca (Jürgen, 2026-11-17): el logo no se deforma ni se recolorea. Un icono con fondo transparente se
pone sobre blanco, sin tocar sus colores; uno cuadrado y opaco se usa tal cual.
"""

from __future__ import annotations

import argparse
import concurrent.futures as futures
import html.parser
import io
import json
import re
import shutil
import subprocess
import threading
import time
import sys
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Yala/App/Logic/MerchantLogos/MerchantCatalog.json"
ASSETS = ROOT / "Yala/App/Logic/MerchantLogos/MerchantLogos.xcassets"
OUTPUT_PX = 120  # el distintivo más grande mide 40 pt: 120 px a 3x
MIN_PX = 64
UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) "
    "Version/17.0 Safari/605.1.15"
)


def load_catalog() -> list[dict]:
    return json.loads(CATALOG.read_text(encoding="utf-8"))


def save_catalog(entries: list[dict]) -> None:
    # Una entrada por línea: los diffs se leen por comercio.
    lines = [json.dumps(e, ensure_ascii=False, separators=(", ", ": ")) for e in entries]
    CATALOG.write_text("[\n  " + ",\n  ".join(lines) + "\n]\n", encoding="utf-8")


def asset_name(domain: str) -> str:
    return "merchant-" + re.sub(r"[^a-z0-9]+", "-", domain.lower()).strip("-")


def get(url: str, timeout: float = 12) -> tuple[bytes, str] | None:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            if resp.status != 200:
                return None
            return resp.read(4_000_000), resp.geturl()
    except Exception:
        return None


class IconLinks(html.parser.HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.links: list[tuple[int, int, str]] = []  # (prioridad, tamaño declarado, href)
        self.manifest: str | None = None

    def handle_starttag(self, tag, attrs):
        if tag != "link":
            return
        a = {k.lower(): (v or "") for k, v in attrs}
        rel = a.get("rel", "").lower()
        href = a.get("href", "")
        if not href or href.startswith("data:"):
            return
        if rel == "manifest":
            self.manifest = href
            return
        sizes = re.findall(r"(\d+)x\d+", a.get("sizes", ""))
        size = max((int(s) for s in sizes), default=0)
        if href.lower().split("?")[0].endswith(".svg"):
            size = 512  # vectorial: se rasteriza al tamaño que haga falta
        if "apple-touch-icon" in rel:
            self.links.append((2, size or 180, href))
        elif "icon" in rel:
            self.links.append((1, size, href))


def candidates(domain: str) -> list[str]:
    urls: list[str] = []
    hosts = [domain] if domain.startswith("www.") or domain.count(".") > 2 else [domain, f"www.{domain}"]
    for host in hosts:
        page = get(f"https://{host}/")
        if not page:
            continue
        body, final = page
        parser = IconLinks()
        try:
            parser.feed(body.decode("utf-8", "ignore"))
        except Exception:
            pass
        for _, _, href in sorted(parser.links, key=lambda x: (x[0], x[1]), reverse=True)[:5]:
            urls.append(urllib.parse.urljoin(final, href))
        if parser.manifest:
            manifest_url = urllib.parse.urljoin(final, parser.manifest)
            got = get(manifest_url)
            if got:
                try:
                    icons = json.loads(got[0].decode("utf-8", "ignore")).get("icons", [])
                    icons = sorted(icons, key=lambda i: max((int(x) for x in re.findall(r"(\d+)x", i.get("sizes", ""))), default=0), reverse=True)
                    urls += [urllib.parse.urljoin(manifest_url, i["src"]) for i in icons[:2] if i.get("src")]
                except Exception:
                    pass
        break
    for host in hosts:
        for path in ("apple-touch-icon.png", "apple-touch-icon-precomposed.png", "android-chrome-192x192.png",
                     "favicon-196x196.png", "favicon.ico"):
            urls.append(f"https://{host}/{path}")
    urls.append(
        "https://t3.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL"
        f"&url=https://{domain}&size=256"
    )
    urls.append(f"https://icons.duckduckgo.com/ip3/{domain}.ico")
    return urls


STOP = {"banco", "de", "del", "la", "el", "los", "las", "the", "of", "and", "y", "inc", "sa", "sac", "saa", "llc",
        "ltd", "pte", "peru", "mexico", "colombia", "chile", "app", "s", "a", "c", "group", "grupo", "company", "co"}


def norm(text: str) -> str:
    import unicodedata

    text = unicodedata.normalize("NFKD", text.lower())
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return " ".join(re.sub(r"[^a-z0-9+ ]", " ", text).split())


_itunes_lock = threading.Lock()
_itunes_last = [0.0]


def app_store_icon(entry: dict) -> bytes | None:
    """Respaldo: el icono público de su app en el App Store (API de búsqueda de iTunes, sin clave).

    Solo vale si el nombre de la app contiene el del comercio (o una forma de escribirlo) Y el desarrollador es el
    comercio: su web es el dominio del banco o su nombre comparte una palabra con el comercio.
    """
    names = [norm(n) for n in [entry["name"]] + entry.get("aliases", []) if len(norm(n)) >= 3]
    root = entry["domain"].split(".")[0].replace("www", "")
    own = {w for n in names for w in n.split() if w not in STOP} | {root}
    for country in ("pe", "us"):
        with _itunes_lock:  # la API admite ~20 consultas por minuto
            wait = 3.2 - (time.time() - _itunes_last[0])
            if wait > 0:
                time.sleep(wait)
            _itunes_last[0] = time.time()
        term = urllib.parse.quote(entry["name"])
        got = get(f"https://itunes.apple.com/search?term={term}&country={country}&entity=software&limit=8")
        if not got:
            continue
        try:
            results = json.loads(got[0]).get("results", [])
        except Exception:
            continue
        for r in results:
            track = norm(r.get("trackName", ""))
            if not any(track == n or re.search(rf"(^| ){re.escape(n)}( |$)", track) for n in names):
                continue
            seller_url = (r.get("sellerUrl") or "").lower()
            seller = set(norm(r.get("sellerName", "")).split()) - STOP
            if entry["domain"] in seller_url or (own & seller):
                art = r.get("artworkUrl512") or r.get("artworkUrl100")
                image = get(art) if art else None
                if image:
                    return image[0]
    return None


def decode(data: bytes):
    from PIL import Image

    head = data[:400].lstrip().lower()
    if head.startswith(b"<svg") or (head.startswith(b"<?xml") and b"<svg" in data[:2000].lower()):
        try:
            data = subprocess.run(
                ["magick", "-background", "none", "-density", "600", "svg:-", "-resize", "256x256", "png:-"],
                input=data, capture_output=True, timeout=30, check=True,
            ).stdout
        except Exception:
            return None
    try:
        img = Image.open(io.BytesIO(data))
        if getattr(img, "format", "") == "ICO":
            sizes = sorted(img.info.get("sizes", []), key=lambda s: s[0] * s[1])
            if sizes:
                img.size = sizes[-1]
        img.load()
        return img.convert("RGBA")
    except Exception:
        return None


def best_icon(entry: dict, cache: Path | None):
    domain = entry["domain"]
    raw = cache / f"{asset_name(domain)}.bin" if cache else None
    if raw and raw.exists():
        cached = decode(raw.read_bytes())
        if cached is not None and min(cached.size) >= MIN_PX:
            return cached
    best, best_bytes = None, None
    for url in candidates(domain):
        got = get(url)
        if not got:
            continue
        img = decode(got[0])
        if img is None:
            continue
        side = min(img.size)
        if best is None or side > min(best.size):
            best, best_bytes = img, got[0]
        if side >= 180:
            break
    if best is None or min(best.size) < 96:
        store = app_store_icon(entry)
        img = decode(store) if store else None
        if img is not None and (best is None or min(img.size) > min(best.size)):
            best, best_bytes = img, store
    if raw and best_bytes:
        raw.write_bytes(best_bytes)
    return best


def finish(img):
    """Cuadrado de 120 px sin deformar: transparente ⇒ sobre blanco con aire; opaco ⇒ tal cual.

    La app lo pinta en un círculo, como el resto de iconos de la fila: el logo transparente ocupa el 66 % del lado, que
    cabe entero en el círculo (la esquina de ese cuadrado queda a 0,47 del centro, dentro del radio 0,5).
    """
    from PIL import Image

    w, h = img.size
    alpha = img.getchannel("A")
    transparent = sum(1 for a in alpha.getdata() if a < 250) / (w * h)
    if transparent > 0.02:
        bbox = alpha.point(lambda a: 255 if a > 8 else 0).getbbox() or (0, 0, w, h)
        img = img.crop(bbox)
        w, h = img.size
        inner = int(OUTPUT_PX * 0.66)
        scale = inner / max(w, h)
        logo = img.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)
        canvas = Image.new("RGBA", (OUTPUT_PX, OUTPUT_PX), (255, 255, 255, 255))
        canvas.alpha_composite(logo, ((OUTPUT_PX - logo.width) // 2, (OUTPUT_PX - logo.height) // 2))
        return canvas.convert("RGB")
    side = min(w, h)
    img = img.crop(((w - side) // 2, (h - side) // 2, (w - side) // 2 + side, (h - side) // 2 + side))
    return img.convert("RGB").resize((OUTPUT_PX, OUTPUT_PX), Image.LANCZOS)


def write_asset(name: str, img) -> None:
    folder = ASSETS / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    # Paleta de 256 colores si no se nota (error cuadrático medio < 3 de 255): un logo plano pesa la mitad. Un icono
    # con degradados o foto se queda en color completo.
    from PIL import Image, ImageChops, ImageStat

    quantized = img.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
    error = sum(ImageStat.Stat(ImageChops.difference(img, quantized.convert("RGB"))).rms) / 3
    (quantized if error < 3 else img).save(folder / "logo.png", optimize=True)
    contents = {
        "images": [{"filename": "logo.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def cmd_fetch(args) -> int:
    entries = load_catalog()
    ASSETS.mkdir(parents=True, exist_ok=True)
    (ASSETS / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    only = set(args.only.split(",")) if args.only else None
    first_by_domain: dict[str, dict] = {}
    for e in entries:
        if (only is None or e["id"] in only) and not e.get("noLogo"):
            first_by_domain.setdefault(e["domain"], e)
    domains = sorted(first_by_domain)
    if not args.force:
        domains = [d for d in domains if not (ASSETS / f"{asset_name(d)}.imageset").exists()]

    cache = Path(args.cache) if args.cache else None
    if cache:
        cache.mkdir(parents=True, exist_ok=True)

    def work(domain: str):
        img = best_icon(first_by_domain[domain], cache)
        if img is None or min(img.size) < MIN_PX:
            return domain, None
        write_asset(asset_name(domain), finish(img))
        return domain, min(img.size)

    with futures.ThreadPoolExecutor(max_workers=16) as pool:
        for domain, size in pool.map(work, domains):
            print(f"{'OK ' if size else '-- '} {domain} {size or ''}", flush=True)

    for e in entries:
        if not e.get("noLogo") and (ASSETS / f"{asset_name(e['domain'])}.imageset").exists():
            e["logo"] = asset_name(e["domain"])
        else:
            e.pop("logo", None)
    # Lo que ya nadie usa sale del catálogo de imágenes.
    used = {e.get("logo") for e in entries}
    for folder in ASSETS.glob("*.imageset"):
        if folder.stem not in used:
            shutil.rmtree(folder)
    save_catalog(entries)
    with_logo = sum(1 for e in entries if e.get("logo"))
    print(f"\n{with_logo}/{len(entries)} comercios con logo")
    return 0


def cmd_check(_args) -> int:
    entries = load_catalog()
    ids = [e["id"] for e in entries]
    problems = [f"id repetido: {i}" for i in sorted({i for i in ids if ids.count(i) > 1})]
    for e in entries:
        if e.get("logo") and not (ASSETS / f"{e['logo']}.imageset" / "logo.png").exists():
            problems.append(f"{e['id']}: falta la imagen {e['logo']}")
    print("\n".join(problems) or f"OK · {len(entries)} comercios")
    return 1 if problems else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    f = sub.add_parser("fetch")
    f.add_argument("--only")
    f.add_argument("--force", action="store_true")
    f.add_argument("--cache", help="carpeta donde guardar lo descargado, para reprocesar sin volver a bajar")
    f.set_defaults(func=cmd_fetch)
    sub.add_parser("check").set_defaults(func=cmd_check)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
