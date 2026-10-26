#!/usr/bin/env python3
"""Revisión de traducciones de Yala: comprobaciones deterministas + una pasada de Sonnet por idioma.

Uso típico (antes de cada release, solo lo que cambió desde la anterior):

    python3 qa/l10n-review/review.py --since v2.1.0

Corrida completa (la primera, o cuando haga falta):

    python3 qa/l10n-review/review.py --full

Escribe en `qa/l10n-review/informes/<fecha>/`: un `<idioma>.json` con los hallazgos y un `resumen.md`.
Los trozos ya revisados se guardan en caché (`~/Library/Caches/Yala/l10n-review/`), así que una
corrida cortada se retoma sin repetir lo hecho. Detalle en `qa/l10n-review/README.md`.
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from l10n_common import (  # noqa: E402
    ALIASES, BASES, PARENT_OF, REFERENCE, REPO, VARIANTS, is_protected, load_protected,
    placeholders, read_plurals, read_strings, read_strings_text, strings_path,
)

LANG_NAMES = {
    "es-419": "español neutro latinoamericano", "en": "inglés de EE. UU.", "de": "alemán",
    "fr": "francés", "it": "italiano", "nl": "neerlandés", "pl": "polaco",
    "pt-BR": "portugués de Brasil", "pt-PT": "portugués de Portugal", "ja": "japonés",
    "zh-Hans": "chino simplificado", "en-GB": "inglés británico", "es-ES": "español de España",
    "es-AR": "español de Argentina",
}

GUIDES = {
    "es-419": "Español NEUTRO latinoamericano, tuteo («tú»). Marca como «regional» toda palabra que no se entienda igual "
              "en México, Colombia, Perú y Argentina (peruanismos como «bodega», «chamba», «jato»; españolismos como «vale», "
              "«ordenador», «móvil», «coger»). Nada de voseo. Revisa tildes y signos de apertura (¿ ¡).",
    "en": "US English, second person «you», friendly and direct. US spelling and US date order. No British spellings.",
    "en-GB": "British English: British spelling (colour, organise, cancelled), «mobile» not «cell phone». Only report what "
             "is wrong for a UK reader.",
    "es-ES": "Español de España, tuteo. Vocabulario peninsular donde difiera («móvil», «ordenador»). Nada de voseo.",
    "es-AR": "Español de Argentina con VOSEO verbal (vos tenés/podés/sos). Sin modismos coloquiales (guita, che, boludo).",
    "de": "Deutsch, informelles «du» (nicht «Sie»). Komposita korrekt zusammengeschrieben, Umlaute vorhanden.",
    "fr": "Français, vouvoiement OU tutoiement selon l'usage déjà dominant dans les entrées — signale les incohérences. "
          "ACCENTS obligatoires (é è ê à ç ô û î): «Paramètres», «Catégories», «Dépenses», «données», «Sélectionner». "
          "Espace insécable avant « : ; ? ! ». Apostrophes typographiques acceptées.",
    "it": "Italiano, «tu» informale. Accenti corretti (è, perché, più, già).",
    "nl": "Nederlands, informeel «je/jouw» (niet «u»).",
    "pl": "Polski, forma nieformalna («ty»). Polskie znaki (ą ć ę ł ń ó ś ź ż).",
    "pt-BR": "Português do Brasil, «você». Vocabulário do Brasil (celular, tela, excluir, gerenciar, salvar). "
             "Marca como «regional» qualquer forma de Portugal (telemóvel, ecrã, eliminar, gerir, guardar, «tu» + 2ª pessoa, "
             "«registos»). Acentos obrigatórios (ção, não, é, você, orçamento).",
    "pt-PT": "Português EUROPEU (Portugal), tratamento por «tu» com 2.ª pessoa nas frases conversacionais. Vocabulário de "
             "Portugal: telemóvel, ecrã, eliminar, gerir, guardar, registo/registos, utilizador, ficheiro, definições. "
             "Marca como «regional» toda forma do Brasil (você + 3.ª pessoa em frases dirigidas ao utilizador, celular, tela, "
             "excluir, gerenciar, salvar, registro, usuário, arquivo, «Configurações»). Ortografia AO90 (ação, ótimo, "
             "receção). Textos ainda em inglês = «sin_traducir».",
    "ja": "自然な日本語（です・ます調）。用語は一貫させる。英語のまま残っている文は「sin_traducir」。",
    "zh-Hans": "简体中文，自然、简洁。用语保持一致。仍为英文的句子标记为「sin_traducir」。",
}

ANCHOR_KEYS = [
    "tab.panel", "tab.statistics", "tab.records", "tab.groups", "tab.more", "settings.title", "categories.title",
    "subcategories.title", "budgets.title", "planning.scheduledPayments", "transaction.tags", "transaction.type.expense",
    "transaction.type.income", "transaction.transfer", "settings.accounts", "settings.currency", "trend.title",
    "inbox.title",
]

CATEGORIES = ["sin_traducir", "ortografia", "significado", "terminologia", "registro", "regional", "placeholder", "longitud"]

PROMPT = """Eres revisor/a nativo/a de {lang_name} para Yala, una app iOS de finanzas personales (gastos, cuentas,
presupuestos, grupos para dividir gastos, y un asistente «Yala IA»). Revisa las traducciones de abajo.

Referencias: «es» (español latinoamericano) es el ORIGINAL y manda en el significado; «en» es la segunda referencia.
«t» es el texto que ve el usuario en {lang_name}. La clave («k») da contexto de pantalla.

Guía del idioma: {guide}

Así nombra la app sus conceptos en {lang_name} hoy (úsalo para juzgar la consistencia, y avisa si alguno está mal):
{glossary}

Reglas:
- Reporta SOLO defectos reales que un usuario nativo notaría. Si una entrada está bien, no la menciones.
- No reescribas por estilo ni por gusto. No propongas sinónimos equivalentes.
- «Yala», «Yala IA», «Yala Pro», «iCloud», «Apple Pay», «Face ID», «Siri» y los nombres de marcas no se traducen.
- La propuesta conserva EXACTAMENTE los placeholders (%@, %d, %ld, %1$@, %2$d, %%) y los escapes (\\n, \\").
- La propuesta no debe ser mucho más larga que «t» salvo que el defecto lo exija (son botones y etiquetas de iPhone).
- categoria ∈ {categories}
  (sin_traducir: sigue en otro idioma · ortografia: tildes, erratas, mayúsculas · significado: dice otra cosa que «es» ·
   terminologia: nombra un concepto distinto que el resto de la app · registro: tú/usted, você/tu… incoherente con la guía ·
   regional: palabra de otro país · placeholder: falta o sobra uno · longitud: tan largo que se cortará)
- gravedad: «alta» (error visible o significado falso), «media» (claramente incorrecto pero se entiende), «baja» (mejorable).

Responde SOLO con un array JSON (sin texto antes ni después, sin ```), un objeto por defecto:
[{{"k": "<clave>", "categoria": "...", "gravedad": "...", "propuesta": "<texto corregido, con escapes como en t>", "motivo": "<una frase en español>"}}]
Si no hay defectos, responde [].

Entradas (una por línea, JSON):
{entries}
"""


def git_show(ref: str, path: Path) -> str:
    rel = path.relative_to(REPO)
    try:
        return subprocess.run(["git", "-C", str(REPO), "show", f"{ref}:{rel}"], capture_output=True, text=True,
                              check=True).stdout
    except subprocess.CalledProcessError:
        return ""


def deterministic(locale: str, ref: dict, en: dict, target: dict, protected: list[str]) -> list[dict]:
    """Lo que no necesita a nadie: claves que faltan, placeholders, restos en inglés o en español."""
    out = []
    for key, es_val in ref.items():
        if key not in target:
            out.append({"k": key, "categoria": "falta", "gravedad": "alta", "motivo": "La clave no está en este idioma."})
            continue
        t = target[key]
        if placeholders(t) != placeholders(es_val):
            out.append({"k": key, "categoria": "placeholder", "gravedad": "alta",
                        "motivo": f"Placeholders {placeholders(t)} ≠ referencia {placeholders(es_val)}."})
        if locale not in ("en", "en-GB") and not locale.startswith("es"):
            en_val = en.get(key, "")
            if t == en_val and t != es_val and len(re.findall(r"[A-Za-z]{3,}", t)) >= 3:
                out.append({"k": key, "categoria": "sin_traducir", "gravedad": "media",
                            "motivo": "Idéntica al inglés (posible resto sin traducir)."})
            elif t == es_val and t != en_val and len(re.findall(r"[A-Za-zÁÉÍÓÚáéíóúñ]{3,}", t)) >= 3:
                out.append({"k": key, "categoria": "sin_traducir", "gravedad": "media",
                            "motivo": "Idéntica al español (posible resto sin traducir)."})
    for f in out:
        f["fuente"] = "determinista"
        f["actual"] = target.get(f["k"], "")
        f["protegida"] = is_protected(f["k"], protected)
    return out


def call_claude(prompt: str, model: str, backend: str, workdir: str, timeout: int) -> str:
    if backend == "api":
        import urllib.request
        key = os.environ.get("ANTHROPIC_API_KEY")
        if not key:
            raise SystemExit("--backend api necesita ANTHROPIC_API_KEY en el entorno (no se lee de ningún fichero).")
        body = json.dumps({"model": model, "max_tokens": 16000, "messages": [{"role": "user", "content": prompt}]})
        req = urllib.request.Request("https://api.anthropic.com/v1/messages", data=body.encode(), headers={
            "x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json"})
        with urllib.request.urlopen(req, timeout=timeout) as r:
            data = json.loads(r.read())
        return "".join(b.get("text", "") for b in data.get("content", []))
    # CLI de Claude Code: va con la suscripción. Sin hooks (no carga settings de usuario) ni herramientas.
    cmd = ["claude", "-p", "--model", model, "--setting-sources", "project", "--no-session-persistence",
           "--tools", "", "--output-format", "json"]
    res = subprocess.run(cmd, input=prompt, capture_output=True, text=True, cwd=workdir, timeout=timeout)
    if res.returncode != 0:
        raise RuntimeError(f"claude salió {res.returncode}: {res.stderr[-400:]} {res.stdout[-400:]}")
    data = json.loads(res.stdout)
    if data.get("is_error"):
        raise RuntimeError(f"claude devolvió error: {str(data)[:400]}")
    return data.get("result", "")


def parse_findings(text: str) -> list[dict]:
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text)
    start, end = text.find("["), text.rfind("]")
    if start < 0 or end < start:
        raise ValueError(f"respuesta sin array JSON: {text[:200]}")
    return json.loads(text[start:end + 1])


def review_chunk(job: dict, args, cache_dir: Path, workdir: str) -> list[dict]:
    digest = hashlib.sha256((args.model + job["prompt"]).encode()).hexdigest()[:20]
    cache = cache_dir / f"{job['locale']}-{digest}.json"
    if cache.exists():
        return json.loads(cache.read_text())
    last = None
    for attempt in range(4):
        try:
            findings = parse_findings(call_claude(job["prompt"], args.model, args.backend, workdir, args.timeout))
            cache.write_text(json.dumps(findings, ensure_ascii=False))
            return findings
        except Exception as e:  # noqa: BLE001 — reintento con espera creciente; el último error se informa
            last = e
            time.sleep(10 * (attempt + 1))
    print(f"  ✗ {job['locale']} trozo {job['n']}: {last}", file=sys.stderr)
    return [{"k": "__trozo_fallido__", "categoria": "error", "gravedad": "alta", "motivo": str(last)[:300],
             "trozo": job["n"]}]


def build_entries(locale: str, keys: list[str], ref: dict, en: dict, target: dict) -> list[str]:
    rows = []
    for k in keys:
        row = {"k": k, "es": ref.get(k, ""), "en": en.get(k, ""), "t": target[k]}
        if locale == REFERENCE:
            row.pop("t")
            row["t"] = ref[k]
        rows.append(json.dumps(row, ensure_ascii=False))
    return rows


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    scope = ap.add_mutually_exclusive_group(required=True)
    scope.add_argument("--full", action="store_true", help="revisa el catálogo entero")
    scope.add_argument("--since", metavar="REF", help="solo las claves que cambiaron desde REF (p. ej. v2.1.0)")
    ap.add_argument("--locales", nargs="*", help="limita a estos idiomas")
    ap.add_argument("--model", default="sonnet")
    ap.add_argument("--backend", choices=["cli", "api"], default="cli")
    ap.add_argument("--chunk", type=int, default=150)
    ap.add_argument("--jobs", type=int, default=6)
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--no-llm", action="store_true", help="solo las comprobaciones deterministas")
    ap.add_argument("--max-chunks", type=int, default=0, help="prueba: como mucho N trozos por idioma")
    ap.add_argument("--out", default=None, help="carpeta del informe (por defecto informes/<fecha>)")
    args = ap.parse_args()

    today = dt.date.today().isoformat()
    out_dir = Path(args.out) if args.out else Path(__file__).parent / "informes" / today
    out_dir.mkdir(parents=True, exist_ok=True)
    cache_dir = Path.home() / "Library" / "Caches" / "Yala" / "l10n-review"
    cache_dir.mkdir(parents=True, exist_ok=True)
    workdir = tempfile.mkdtemp(prefix="yala-l10n-review-")
    protected = load_protected()

    ref = read_strings(strings_path(REFERENCE))
    en = read_strings(strings_path("en"))
    locales = args.locales or (BASES + list(VARIANTS))
    findings: dict[str, list[dict]] = {}
    jobs = []

    # Alias: copia idéntica de su base.
    for alias, base in ALIASES.items():
        if args.locales and alias not in args.locales:
            continue
        a, b = read_strings(strings_path(alias)), read_strings(strings_path(base))
        diff = sorted(k for k in set(a) | set(b) if a.get(k) != b.get(k))
        findings[alias] = [{"k": k, "categoria": "alias", "gravedad": "alta", "fuente": "determinista",
                            "motivo": f"Difiere de {base}: el alias debe ser copia idéntica."} for k in diff]

    for locale in locales:
        target = read_strings(strings_path(locale))
        found = deterministic(locale, ref, en, target, protected) if locale != REFERENCE else []
        parent = PARENT_OF.get(locale)
        if locale in VARIANTS:
            pvals = read_strings(strings_path(parent))
            keys = [k for k in target if k in pvals and target[k] != pvals[k]]
        else:
            keys = [k for k in target if k in ref]
        if args.since:
            old_ref = read_strings_text(git_show(args.since, strings_path(REFERENCE)))
            old_t = read_strings_text(git_show(args.since, strings_path(locale)))
            keys = [k for k in keys if old_ref.get(k) != ref.get(k) or old_t.get(k) != target.get(k)]
        # Textos de permisos (InfoPlist) y plurales, como entradas extra.
        extra_t, extra_ref, extra_en = {}, {}, {}
        ip_t, ip_ref, ip_en = (read_strings(strings_path(x, "InfoPlist")) for x in (locale, REFERENCE, "en"))
        for k, v in ip_t.items():
            extra_t[f"InfoPlist:{k}"], extra_ref[f"InfoPlist:{k}"], extra_en[f"InfoPlist:{k}"] = v, ip_ref.get(k, ""), ip_en.get(k, "")
        if locale not in VARIANTS:
            pl_t, pl_ref, pl_en = read_plurals(locale), read_plurals(REFERENCE), read_plurals("en")
            for k, forms in pl_t.items():
                for form, v in forms.items():
                    kk = f"{k}#{form}"
                    other = form.rsplit(".", 1)[0] + ".other" if "." in form else form
                    extra_t[kk] = v
                    extra_ref[kk] = pl_ref.get(k, {}).get(form) or pl_ref.get(k, {}).get(other, "")
                    extra_en[kk] = pl_en.get(k, {}).get(form) or pl_en.get(k, {}).get(other, "")
        if not args.since:
            keys += list(extra_t)
        all_t, all_ref, all_en = {**target, **extra_t}, {**ref, **extra_ref}, {**en, **extra_en}
        findings[locale] = found
        if args.no_llm or not keys:
            continue
        tgt_for_gloss = target if locale != REFERENCE else ref
        glossary = "\n".join(f"  {k}: es «{ref.get(k, '')}» → «{tgt_for_gloss.get(k, '')}»" for k in ANCHOR_KEYS if k in ref)
        for n, i in enumerate(range(0, len(keys), args.chunk)):
            if args.max_chunks and n >= args.max_chunks:
                break
            chunk = keys[i:i + args.chunk]
            prompt = PROMPT.format(lang_name=LANG_NAMES[locale], guide=GUIDES[locale], glossary=glossary,
                                   categories=", ".join(CATEGORIES),
                                   entries="\n".join(build_entries(locale, chunk, all_ref, all_en, all_t)))
            jobs.append({"locale": locale, "n": n, "prompt": prompt, "keys": chunk, "target": all_t})

    print(f"{len(jobs)} trozos para el LLM ({args.model}, backend {args.backend}), {args.jobs} en paralelo.")
    done = 0
    with cf.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futs = {pool.submit(review_chunk, j, args, cache_dir, workdir): j for j in jobs}
        for fut in cf.as_completed(futs):
            job = futs[fut]
            for f in fut.result():
                k = f.get("k", "")
                f["fuente"] = "llm"
                f["actual"] = job["target"].get(k, "")
                f["protegida"] = is_protected(k, protected)
                if f.get("propuesta") is not None and k in job["target"]:
                    f["placeholders_ok"] = placeholders(f["propuesta"]) == placeholders(job["target"][k])
                findings[job["locale"]].append(f)
            done += 1
            if done % 10 == 0 or done == len(jobs):
                print(f"  {done}/{len(jobs)} trozos")

    for locale, items in findings.items():
        (out_dir / f"{locale}.json").write_text(json.dumps(items, ensure_ascii=False, indent=1))
    lines = [f"# Revisión de traducciones · {today}", "",
             f"Alcance: {'catálogo entero' if args.full else 'cambios desde ' + args.since}. Modelo: {args.model} "
             f"({args.backend}). Referencia: {REFERENCE}.", "",
             "| Idioma | Alta | Media | Baja | Protegidas | Trozos fallidos |", "|---|---|---|---|---|---|"]
    for locale, items in findings.items():
        c = {g: sum(1 for f in items if f.get("gravedad") == g and f.get("k") != "__trozo_fallido__") for g in ("alta", "media", "baja")}
        lines.append(f"| {locale} | {c['alta']} | {c['media']} | {c['baja']} | "
                     f"{sum(1 for f in items if f.get('protegida'))} | "
                     f"{sum(1 for f in items if f.get('k') == '__trozo_fallido__')} |")
    (out_dir / "resumen.md").write_text("\n".join(lines) + "\n")
    print(f"Informe en {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
