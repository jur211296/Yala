#!/usr/bin/env python3
"""
Corpus del banco de voz: genera y descarga el audio que mide `voice/run.ts`.

    python3 -I gateway/bench/voice/corpus.py tts     # notas sintéticas limpias → cases/voice/audio/*.m4a (se commitean)
    python3 -I gateway/bench/voice/corpus.py noise   # versiones con ruido de calle → .cache/voice/noisy/ (no se commitean)
    python3 -I gateway/bench/voice/corpus.py real    # habla humana de corpus abiertos → .cache/voice/real/ (no se commitean)
    python3 -I gateway/bench/voice/corpus.py all

Solo biblioteca estándar + `ffmpeg` y `say` (macOS). Reanudable: lo que ya existe no se rehace.

Audio: como lo manda la app (`AudioRecorderService`: AAC en .m4a, mono, 16 kHz). Bitrate 32 kbps.

TTS (al menos dos motores distintos, para no sesgar: un motor de transcripción del mismo proveedor que el TTS puede
salir favorecido, y el manifiesto `clips.json` dice con qué motor se generó cada clip):
  - `say`: voces de macOS (Apple). Dos voces por variante, alternas por nota.
  - `gemini`: Gemini TTS (`gemini-3.8-flash-lite-tts`, API Interactions), voces regionales de su biblioteca
    (es-419 con acento argentino o mexicano, es-ES, pt-PT, pl-PL…). Doc: ai.google.dev/gemini-api/docs/speech-generation
    (consultada el 2026-10-07).
  - `openai`: solo es-PE (6 clips), `gpt-4o-mini-tts` con instrucciones de acento peruano: ninguna voz de macOS ni
    de Gemini es peruana. Doc: developers.openai.com/api/docs/guides/text-to-speech.

Ruido de calle, reproducible con semilla (crc32 del id del clip + condición): tráfico (ruido marrón con pasadas
de coches), ruido rosa y murmullo de voces (otras cuatro notas del corpus, invertidas para que no se entiendan
palabras, a bajo nivel). Se escala para una SNR de 10 dB y 5 dB sobre la potencia de los tramos con voz, con
0,6 s de ruido antes y después (la persona empieza a grabar en la calle). Cada nota tiene UNA versión ruidosa por
SNR, de su clip `say` (notas impares) o `gemini` (pares), para no duplicar el coste.

Habla real (no se commitea el audio; el manifiesto `cases/voice/real.json` guarda ids, textos, fuente y licencia):
  - OpenSLR 73 (Google, CC BY-SA 4.0): español peruano. 15 clips de mujeres y 15 de hombres, un hablante por clip,
    leídos del zip remoto por rangos HTTP (no se baja el zip de 900 MB).
  - FLEURS (Google, CC BY 4.0): 5 clips por idioma de los 10, del principio de `dev.tar.gz` en streaming.
"""
import base64
import binascii
import io
import json
import os
import random
import struct
import subprocess
import sys
import tarfile
import time
import urllib.error
import urllib.request
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
BENCH = os.path.dirname(HERE)
CASES = os.path.join(BENCH, "cases", "voice")
AUDIO = os.path.join(CASES, "audio")
CACHE = os.path.join(BENCH, ".cache", "voice")
SECRETS = os.path.expanduser("~/Secrets/yala-ai-bench")
SR = 16000

SAY_VOICES = {
    "es-PE": ["Paulina", "Eddy (Español (México))"],
    "es-AR": ["Reed (Español (México))", "Sandy (Español (México))"],
    "es-ES": ["Mónica", "Eddy (Español (España))"],
    "en-US": ["Samantha", "Reed (Inglés (EE. UU.))"],
    "en-GB": ["Daniel", "Flo (Inglés (RU))"],
    "pt-BR": ["Luciana", "Eddy (Portugués (Brasil))"],
    "pt-PT": ["Joana", "Joana"],
    "fr-FR": ["Thomas", "Jacques"],
    "de-DE": ["Anna", "Eddy (Alemán (Alemania))"],
    "it-IT": ["Alice", "Eddy (Italiano (Italia))"],
    "nl-NL": ["Xander", "Ellen"],
    "pl-PL": ["Zosia", "Zosia"],
    "ja-JP": ["Kyoko", "Eddy (Japonés (Japón))"],
    "zh-Hans": ["Tingting", "Eddy (Chino (China continental))"],
}

# Voces de la biblioteca de Gemini (GET /v1beta/voices, 2026-10-07). zh no tiene voces regionales: se usan
# las prediseñadas, que detectan el idioma.
GEMINI_VOICES = {
    "es-PE": ["es-419-assistant-1", "es-419-advisor-4"],      # Mexico Spanish (no hay peruana)
    "es-AR": ["es-419-assistant-5", "es-419-advisor-1"],      # Argentina Spanish
    "es-ES": None, "en-US": None, "en-GB": None, "pt-BR": None, "pt-PT": None, "fr-FR": None,
    "de-DE": None, "it-IT": None, "nl-NL": None, "pl-PL": None, "ja-JP": None,
    "zh-Hans": ["Kore", "Puck"],
}
GEMINI_TTS_MODEL = "gemini-3.8-flash-lite-tts"
GEMINI_STYLE = "casual and natural, like someone quickly dictating a short note into their phone"
OPENAI_TTS_MODEL = "gpt-4o-mini-tts"
OPENAI_ES_PE = ("Habla en español con acento peruano de Lima, tono casual y natural, como quien dicta una nota "
                "rápida en el celular.")


def key(name):
    with open(os.path.join(SECRETS, f"{name}.key")) as f:
        return f.read().strip()


def ffmpeg(args, data=None):
    p = subprocess.run(["ffmpeg", "-loglevel", "error", "-y", *args], input=data, capture_output=True)
    if p.returncode != 0:
        raise RuntimeError(p.stderr.decode()[:400])
    return p.stdout


def to_m4a(src_path, dst_path):
    ffmpeg(["-i", src_path, "-ac", "1", "-ar", str(SR), "-c:a", "aac", "-b:a", "32k", dst_path])


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                         capture_output=True, text=True).stdout.strip()
    return round(float(out), 2)


def load_notes():
    with open(os.path.join(CASES, "notes.json")) as f:
        return json.load(f)


def gemini_voices(locale):
    if GEMINI_VOICES.get(locale):
        return GEMINI_VOICES[locale]
    # Primera voz femenina y primera masculina del idioma, por id: determinista.
    path = os.path.join(CACHE, "gemini-voices.json")
    if not os.path.exists(path):
        vs, tok = [], None
        while True:
            url = "https://generativelanguage.googleapis.com/v1beta/voices?pageSize=1000" + (f"&pageToken={tok}" if tok else "")
            r = json.load(urllib.request.urlopen(urllib.request.Request(url, headers={"x-goog-api-key": key("gemini")})))
            vs += r.get("voices", [])
            tok = r.get("next_page_token") or r.get("nextPageToken")
            if not tok:
                break
        os.makedirs(CACHE, exist_ok=True)
        with open(path, "w") as f:
            json.dump(vs, f)
    with open(path) as f:
        vs = json.load(f)
    mine = sorted((v for v in vs if v.get("language_code") == locale), key=lambda v: v["id"])
    fem = [v["id"] for v in mine if v.get("gender") == "female"]
    mal = [v["id"] for v in mine if v.get("gender") == "male"]
    if not fem or not mal:
        raise RuntimeError(f"sin voces de Gemini para {locale}")
    return [fem[0], mal[0]]


def tts_say(text, voice, out):
    tmp = out + ".aiff"
    subprocess.run(["say", "-v", voice, "-o", tmp, text], check=True)
    to_m4a(tmp, out)
    os.remove(tmp)


def http_json(url, body, headers):
    # El TTS de Gemini contesta 429 en cuanto se le piden varias seguidas: se reintenta con espera creciente.
    for attempt in range(10):
        req = urllib.request.Request(url, data=json.dumps(body).encode(), headers={"Content-Type": "application/json", **headers})
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code not in (429, 500, 503) or attempt == 9:
                raise
            wait = min(90, 10 * (attempt + 1))
            print(f"  {e.code}, reintento en {wait} s", flush=True)
            time.sleep(wait)


def tts_gemini(text, voice, out):
    body = {
        "model": GEMINI_TTS_MODEL,
        "input": [{"type": "user_input", "content": [{"type": "text", "text": text,
                                                      "annotations": [{"type": "speech_metadata", "style": GEMINI_STYLE}]}]}],
        "response_format": {"type": "audio"},
        "generation_config": {"speech_config": [{"voice": voice}]},
    }
    r = http_json("https://generativelanguage.googleapis.com/v1beta/interactions", body, {"x-goog-api-key": key("gemini")})
    data = None
    for step in r.get("steps", []):
        for c in step.get("content", []):
            if c.get("type") == "audio":
                data = c["data"]
    if not data:
        raise RuntimeError(f"Gemini TTS sin audio: {json.dumps(r)[:300]}")
    tmp = out + ".wav"
    with open(tmp, "wb") as f:
        f.write(base64.b64decode(data))
    to_m4a(tmp, out)
    os.remove(tmp)
    return r.get("usage", {})


def tts_openai(text, voice, out):
    req = urllib.request.Request(
        "https://api.openai.com/v1/audio/speech",
        data=json.dumps({"model": OPENAI_TTS_MODEL, "voice": voice, "input": text, "instructions": OPENAI_ES_PE,
                         "response_format": "wav"}).encode(),
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {key('openai')}"})
    tmp = out + ".wav"
    with urllib.request.urlopen(req, timeout=120) as r, open(tmp, "wb") as f:
        f.write(r.read())
    to_m4a(tmp, out)
    os.remove(tmp)


def cmd_tts():
    notes = load_notes()["notes"]
    os.makedirs(AUDIO, exist_ok=True)
    clips_path = os.path.join(CASES, "clips.json")
    clips = {}
    if os.path.exists(clips_path):
        with open(clips_path) as f:
            clips = {c["clip"]: c for c in json.load(f)["clips"]}
    by_locale = {}
    for n in notes:
        by_locale.setdefault(n["locale"], []).append(n)
    for locale, ns in by_locale.items():
        gv = gemini_voices(locale)
        for i, n in enumerate(ns):
            plan = [("say", SAY_VOICES[locale][i % 2]), ("gemini", gv[i % 2])]
            if locale == "es-PE":
                plan.append(("openai", ["coral", "ash"][i % 2]))
            for engine, voice in plan:
                clip = f"{n['id']}.{engine}"
                out = os.path.join(AUDIO, f"{clip}.m4a")
                if not os.path.exists(out):
                    print("tts", clip, voice, flush=True)
                    if engine == "say":
                        tts_say(n["tts"], voice, out)
                    elif engine == "gemini":
                        tts_gemini(n["tts"], voice, out)
                    else:
                        tts_openai(n["tts"], voice, out)
                clips[clip] = {"clip": clip, "note": n["id"], "locale": locale, "tts": engine, "voice": voice,
                               "model": {"say": "macOS say", "gemini": GEMINI_TTS_MODEL, "openai": OPENAI_TTS_MODEL}[engine],
                               "file": f"audio/{clip}.m4a", "seconds": duration(out)}
    with open(clips_path, "w") as f:
        json.dump({"note": "Clips limpios generados por voice/corpus.py tts. `tts` = motor que generó el audio.",
                   "clips": sorted(clips.values(), key=lambda c: c["clip"])}, f, ensure_ascii=False, indent=1)
    print("clips:", len(clips), "MB:", round(sum(os.path.getsize(os.path.join(AUDIO, f)) for f in os.listdir(AUDIO)) / 1e6, 2))


# ---------------- ruido ----------------

def decode_pcm(path):
    raw = ffmpeg(["-i", path, "-f", "s16le", "-ac", "1", "-ar", str(SR), "-"])
    n = len(raw) // 2
    return [s / 32768.0 for s in struct.unpack(f"<{n}h", raw[: n * 2])]


def encode_m4a(samples, out):
    pcm = struct.pack(f"<{len(samples)}h", *(max(-32767, min(32767, int(round(s * 32767)))) for s in samples))
    ffmpeg(["-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-", "-c:a", "aac", "-b:a", "32k", out], data=pcm)


def rms(xs):
    return (sum(x * x for x in xs) / max(1, len(xs))) ** 0.5


def active_power(xs, frame=320):
    """Potencia media de los tramos de 20 ms con voz (energía > 1/10 del RMS del tramo más fuerte)."""
    frames = [xs[i:i + frame] for i in range(0, len(xs) - frame + 1, frame)]
    rs = [rms(f) for f in frames]
    top = max(rs) if rs else 0
    act = [f for f, r in zip(frames, rs) if r > 0.1 * top]
    return sum(sum(x * x for x in f) for f in act) / max(1, sum(len(f) for f in act))


def unit(xs):
    r = rms(xs) or 1.0
    return [x / r for x in xs]


def street_noise(n, rng, babble_sources):
    # Rosa (filtro de Paul Kellet sobre blanco gaussiano).
    b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0
    pink = []
    for _ in range(n):
        w = rng.gauss(0, 1)
        b0 = 0.99886 * b0 + w * 0.0555179
        b1 = 0.99332 * b1 + w * 0.0750759
        b2 = 0.96900 * b2 + w * 0.1538520
        b3 = 0.86650 * b3 + w * 0.3104856
        b4 = 0.55000 * b4 + w * 0.5329522
        b5 = -0.7616 * b5 - w * 0.0168980
        pink.append(b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362)
        b6 = w * 0.115926
    # Tráfico: marrón (integración con fuga) modulado por pasadas de coches.
    brown, acc = [], 0.0
    for _ in range(n):
        acc = 0.997 * acc + rng.gauss(0, 1) * 0.05
        brown.append(acc)
    passes = [(rng.uniform(0, n), rng.uniform(0.5, 1.2) * SR, rng.uniform(0.6, 1.4)) for _ in range(max(2, n // (SR * 3)))]
    traffic = []
    for i, b in enumerate(brown):
        env = 0.35 + sum(a * 2.718281828 ** (-((i - c) / s) ** 2) for c, s, a in passes)
        traffic.append(b * env)
    # Murmullo: voces del corpus invertidas, con desfase y en bucle.
    babble = [0.0] * n
    for src in babble_sources:
        rev = src[::-1]
        off = rng.randrange(len(rev))
        g = rng.uniform(0.5, 1.0)
        for i in range(n):
            babble[i] += g * rev[(i + off) % len(rev)]
    pink, traffic, babble = unit(pink), unit(traffic), unit(babble)
    return [t + 0.5 * p + 0.6 * bb for t, p, bb in zip(traffic, pink, babble)]


def cmd_noise():
    notes = load_notes()["notes"]
    with open(os.path.join(CASES, "clips.json")) as f:
        clips = {c["clip"]: c for c in json.load(f)["clips"]}
    outdir = os.path.join(CACHE, "noisy")
    os.makedirs(outdir, exist_ok=True)
    pool = sorted(c for c in clips if c.endswith(".say") or c.endswith(".gemini"))
    pcm_cache = {}

    def pcm(clip):
        if clip not in pcm_cache:
            pcm_cache[clip] = decode_pcm(os.path.join(CASES, clips[clip]["file"]))
        return pcm_cache[clip]

    by_locale = {}
    for n in notes:
        by_locale.setdefault(n["locale"], []).append(n)
    for locale, ns in by_locale.items():
        for i, n in enumerate(ns):
            base = f"{n['id']}.{'say' if i % 2 == 0 else 'gemini'}"
            for snr in (10, 5):
                out = os.path.join(outdir, f"{base}.snr{snr}.m4a")
                if os.path.exists(out):
                    continue
                seed = binascii.crc32(f"{base}|snr{snr}".encode())
                rng = random.Random(seed)
                speech = pcm(base)
                others = [c for c in pool if not c.startswith(n["id"] + ".")]
                srcs = [pcm(c) for c in rng.sample(others, 4)]
                pad = int(0.6 * SR)
                total = len(speech) + 2 * pad
                noise = street_noise(total, rng, srcs)
                ps = active_power(speech)
                pn = sum(x * x for x in noise) / total
                g = (ps / (pn * 10 ** (snr / 10))) ** 0.5
                mix = [g * x for x in noise]
                for j, s in enumerate(speech):
                    mix[pad + j] += s
                peak = max(abs(x) for x in mix)
                if peak > 0.98:
                    mix = [x * 0.98 / peak for x in mix]
                encode_m4a(mix, out)
                print("noise", os.path.basename(out), f"seed={seed}", flush=True)


# ---------------- habla real ----------------

class HttpFile(io.RawIOBase):
    """Fichero remoto de solo lectura por rangos HTTP, con bloques de 256 KB en memoria (para leer un zip)."""

    BLOCK = 256 * 1024

    def __init__(self, url):
        self.url, self.pos, self.blocks = url, 0, {}
        req = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(req, timeout=60) as r:
            self.size = int(r.headers["Content-Length"])

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, off, whence=0):
        self.pos = off if whence == 0 else self.pos + off if whence == 1 else self.size + off
        return self.pos

    def _block(self, i):
        if i not in self.blocks:
            start, end = i * self.BLOCK, min(self.size, (i + 1) * self.BLOCK) - 1
            req = urllib.request.Request(self.url, headers={"Range": f"bytes={start}-{end}"})
            with urllib.request.urlopen(req, timeout=120) as r:
                self.blocks[i] = r.read()
        return self.blocks[i]

    def read(self, n=-1):
        if n is None or n < 0:
            n = self.size - self.pos
        out = bytearray()
        while n > 0 and self.pos < self.size:
            b = self._block(self.pos // self.BLOCK)
            off = self.pos % self.BLOCK
            chunk = b[off:off + n]
            out += chunk
            self.pos += len(chunk)
            n -= len(chunk)
        return bytes(out)

    def readinto(self, buf):
        data = self.read(len(buf))
        buf[: len(data)] = data
        return len(data)


SLR73 = "https://www.openslr.org/resources/73/{}.zip"
FLEURS = "https://huggingface.co/datasets/google/fleurs/resolve/main/data/{}/{}"
FLEURS_CONFIGS = {"es-419": "es_419", "en-US": "en_us", "pt-BR": "pt_br", "fr-FR": "fr_fr", "de-DE": "de_de",
                  "it-IT": "it_it", "nl-NL": "nl_nl", "pl-PL": "pl_pl", "ja-JP": "ja_jp", "zh-Hans": "cmn_hans_cn"}


def cmd_real():
    outdir = os.path.join(CACHE, "real")
    os.makedirs(outdir, exist_ok=True)
    manifest_path = os.path.join(CASES, "real.json")
    manifest = None
    if os.path.exists(manifest_path):
        with open(manifest_path) as f:
            manifest = json.load(f)
    clips = []
    # --- OpenSLR 73 ---
    for zipname in ("es_pe_female", "es_pe_male"):
        wanted = [c for c in (manifest or {}).get("clips", []) if c["source"] == f"openslr73:{zipname}"]
        z = zipfile.ZipFile(HttpFile(SLR73.format(zipname)))
        names = z.namelist()
        index_name = next(n for n in names if n.endswith("line_index.tsv"))
        texts = {}
        for line in z.read(index_name).decode("utf-8").splitlines():
            parts = line.split("\t")
            if len(parts) >= 2:
                texts[parts[0].strip()] = parts[-1].strip()
        if wanted:
            pick = [c["member"] for c in wanted]
        else:
            by_speaker = {}
            for n in sorted(x for x in names if x.endswith(".wav")):
                fid = os.path.basename(n)[:-4]
                spk = "_".join(fid.split("_")[:2])
                if fid in texts and spk not in by_speaker:
                    by_speaker[spk] = n
            pick = [by_speaker[s] for s in sorted(by_speaker)[:15]]
        for member in pick:
            fid = os.path.basename(member)[:-4]
            cid = f"slr73-{fid}"
            out = os.path.join(outdir, f"{cid}.m4a")
            if not os.path.exists(out):
                tmp = out + ".wav"
                with open(tmp, "wb") as f:
                    f.write(z.read(member))
                to_m4a(tmp, out)
                os.remove(tmp)
                print("real", cid, flush=True)
            clips.append({"clip": cid, "locale": "es-PE", "source": f"openslr73:{zipname}", "member": member,
                          "text": texts[fid], "license": "CC BY-SA 4.0", "url": "https://www.openslr.org/73/",
                          "file": f"real/{cid}.m4a", "seconds": duration(out)})
    # --- FLEURS ---
    for locale, cfg in FLEURS_CONFIGS.items():
        wanted = {c["member"] for c in (manifest or {}).get("clips", []) if c["source"] == f"fleurs:{cfg}"}
        tsv = urllib.request.urlopen(FLEURS.format(cfg, "dev.tsv"), timeout=120).read().decode("utf-8")
        rows = {}
        for line in tsv.splitlines():
            p = line.split("\t")
            if len(p) >= 4:
                rows[p[1]] = p[2]  # file_name → raw_transcription
        got = []
        need = wanted or None
        with urllib.request.urlopen(FLEURS.format(cfg, "audio/dev.tar.gz"), timeout=300) as r:
            tf = tarfile.open(fileobj=r, mode="r|gz")
            for m in tf:
                if not m.isfile() or not m.name.endswith(".wav"):
                    continue
                base = os.path.basename(m.name)
                if base not in rows or (need is not None and m.name not in need):
                    continue
                cid = f"fleurs-{cfg}-{base[:-4]}"
                out = os.path.join(outdir, f"{cid}.m4a")
                data = tf.extractfile(m).read()
                if not os.path.exists(out):
                    tmp = out + ".wav"
                    with open(tmp, "wb") as f:
                        f.write(data)
                    to_m4a(tmp, out)
                    os.remove(tmp)
                    print("real", cid, flush=True)
                got.append({"clip": cid, "locale": locale, "source": f"fleurs:{cfg}", "member": m.name, "text": rows[base],
                            "license": "CC BY 4.0", "url": "https://huggingface.co/datasets/google/fleurs",
                            "file": f"real/{cid}.m4a", "seconds": duration(out)})
                if (need is None and len(got) >= 5) or (need is not None and len(got) >= len(need)):
                    break
        clips += got
    with open(manifest_path, "w") as f:
        json.dump({"note": ("Habla humana real. El audio NO va en el repo: lo baja `voice/corpus.py real` a "
                            ".cache/voice/real/. Atribución: OpenSLR 73 — Guevara-Rukoz et al., «Crowdsourcing Latin "
                            "American Spanish for Low-Resource Text-to-Speech», LREC 2020 (CC BY-SA 4.0); FLEURS — "
                            "Conneau et al., 2022 (CC BY 4.0). Los textos son los de cada corpus, sin cambios."),
                   "clips": clips}, f, ensure_ascii=False, indent=1)
    print("real clips:", len(clips))


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("tts", "all"):
        cmd_tts()
    if what in ("noise", "all"):
        cmd_noise()
    if what in ("real", "all"):
        cmd_real()
