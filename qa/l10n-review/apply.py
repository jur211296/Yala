#!/usr/bin/env python3
"""Aplica a los catálogos las propuestas del informe que pasan los filtros, y deja el resto en el informe.

    python3 qa/l10n-review/apply.py qa/l10n-review/informes/2026-10-25 --dry-run
    python3 qa/l10n-review/apply.py qa/l10n-review/informes/2026-10-25

Qué se aplica (Paso 0 del lote 12.4, D4):
- `ortografia`, `sin_traducir`, `regional` y `significado` de gravedad alta o media;
- `registro` solo hacia el trato de la marca (informal: tú, du, tu, je, 你), salvo en es-AR y pt-PT, donde la
  guía ya fija el registro (voseo, «tu» de Portugal) y se aplica entero;
- nunca lo que cambia el nombre del asistente («Yala AI/IA/KI»), ni el «significado» de `en` (segunda referencia);
- nunca `terminologia`: el muestreo del 2026-10-25 la vio contradecirse entre trozos («Ajustes» y «Configurações» a la
  vez) y renombrar conceptos que son decisión de producto («Panel» frente al nombre de la pestaña).
Y siempre que: la clave no esté protegida, los placeholders de la propuesta sean los del texto actual, y el texto
actual del catálogo siga siendo el que se revisó (si cambió desde la revisión, se salta).

Con varias propuestas para la misma clave gana la de más gravedad, y a igualdad significado > registro > regional >
ortografía > sin traducir. Los alias (`es`, `pt`) se regeneran por copia de su base al final.
"""
from __future__ import annotations

import argparse
import collections
import fnmatch
import json
import plistlib
import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from l10n_common import (  # noqa: E402
    ALIASES, RES, is_protected, load_protected, placeholders, read_strings, strings_path, write_values,
)

APPLY = {"ortografia", "sin_traducir", "regional", "significado", "significato", "registro"}
PRIORITY = {"significado": 5, "significato": 5, "registro": 4, "regional": 3, "ortografia": 2, "sin_traducir": 1}
SEVERITY = {"alta": 3, "media": 2, "baja": 1}
REGISTER_FREE = {"es-AR", "pt-PT"}
# `en` es la segunda referencia: sus «significado» del 2026-10-25 reescribían más que corregían.
NO_MEANING = {"en"}
# El nombre del asistente varía por idioma (Yala AI, Yala KI, Yala IA): es decisión de marca, no de esta revisión.
BRAND = re.compile(r"Yala (?:AI|IA|KI|Pro)\b")
FORMAL = {
    "fr": [r"\bvous\b", r"\bvotre\b", r"\bvos\b", r"\bVous\b", r"\bVotre\b"],
    "de": [r"\bSie\b", r"\bIhr\w*", r"\bIhnen\b"],
    "zh-Hans": [r"您"],
    "pl": [r"\bPan\b", r"\bPani\b", r"\bPaństw\w*"],
    "nl": [r"\bu\b", r"\buw\b"],
    "it": [r"\bLei\b", r"\bSuo\b", r"\bSua\b"],
}
INFORMAL = {
    "fr": [r"\btu\b", r"\bton\b", r"\bta\b", r"\btes\b", r"\bte\b", r"\bt'"],
    "de": [r"\bdu\b", r"\bdein\w*", r"\bdich\b", r"\bdir\b"],
    "zh-Hans": [r"你"],
    "pl": [r"\btwój\b", r"\btwoj\w*", r"\bciebie\b", r"\bcię\b"],
    "nl": [r"\bje\b", r"\bjouw\b", r"\bjij\b"],
    "it": [r"\btu\b", r"\btuo\b", r"\btua\b", r"\btuoi\b", r"\btue\b", r"\bti\b"],
}


def count(text: str, pats: list[str]) -> int:
    return sum(len(re.findall(p, text, flags=re.IGNORECASE if p.islower() else 0)) for p in pats)


def towards_brand_register(locale: str, before: str, after: str) -> bool:
    if locale in REGISTER_FREE:
        return True
    if locale not in FORMAL:
        return False
    return (count(after, FORMAL[locale]) < count(before, FORMAL[locale])
            or count(after, INFORMAL[locale]) > count(before, INFORMAL[locale])) \
        and count(after, FORMAL[locale]) <= count(before, FORMAL[locale])


def eligible(locale: str, f: dict, protected: list[str]) -> str | None:
    """Devuelve el motivo para NO aplicar, o None si se aplica."""
    if f.get("fuente") != "llm" or not f.get("propuesta"):
        return "sin propuesta"
    cat = f.get("categoria")
    if cat not in APPLY:
        return f"categoría {cat}"
    if SEVERITY.get(f.get("gravedad"), 0) < 2:
        return "gravedad baja"
    if cat in ("significado", "significato") and locale in NO_MEANING:
        return "significado en la referencia"
    if BRAND.findall(f["propuesta"]) != BRAND.findall(f.get("actual", "")):
        return "toca la marca"
    if f.get("protegida") or is_protected(f["k"].split("#")[0].removeprefix("InfoPlist:"), protected):
        return "protegida"
    if f["propuesta"] == f.get("actual"):
        return "igual"
    if placeholders(f["propuesta"]) != placeholders(f.get("actual", "")):
        return "placeholders"
    if re.search(r'(?<!\\)"', f["propuesta"]):
        return "comillas sin escapar"
    if locale == "pt-BR" and "Ajustes" in f.get("actual", "") and "Ajustes" not in f["propuesta"] \
            and re.search(r"iPhone|iCloud|\[seu nome\]|\[o teu nome\]|Apple", f.get("actual", "")):
        return "Ajustes es la app de iOS"
    if cat == "registro" and not towards_brand_register(locale, f.get("actual", ""), f["propuesta"]):
        return "registro hacia lo formal"
    return None


def pick(findings: list[dict]) -> dict:
    return max(findings, key=lambda f: (SEVERITY.get(f.get("gravedad"), 0), PRIORITY.get(f.get("categoria"), 0)))


def apply_plurals(locale: str, changes: dict[str, str]) -> int:
    """Claves `clave#var.forma` del informe → su sitio en el `.stringsdict`."""
    path = RES / f"{locale}.lproj" / "Localizable.stringsdict"
    if not changes or not path.exists():
        return 0
    data = plistlib.loads(path.read_bytes())
    done = 0
    for kk, value in changes.items():
        key, form = kk.split("#", 1)
        entry = data.get(key)
        if entry is None:
            continue
        if form == "format":
            entry["NSStringLocalizedFormatKey"] = value
            done += 1
            continue
        var, plural = form.rsplit(".", 1)
        if var in entry and plural in entry[var]:
            entry[var][plural] = value.replace('\\"', '"').replace("\\n", "\n")
            done += 1
    with path.open("wb") as fh:
        plistlib.dump(data, fh, fmt=plistlib.FMT_XML, sort_keys=False)
    return done


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("informe", help="carpeta con los <idioma>.json de review.py")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--locales", nargs="*")
    ap.add_argument("--skip-keys", default=None, help="fichero con claves idioma:clave que no se aplican (revisadas a mano)")
    args = ap.parse_args()

    protected = load_protected()
    skip = set()
    if args.skip_keys:
        skip = {l.strip() for l in Path(args.skip_keys).read_text().split("\n") if l.strip() and not l.startswith("#")}
    out_dir = Path(args.informe)
    log = {}
    for path in sorted(out_dir.glob("*.json")):
        locale = path.stem
        if locale in ALIASES or (args.locales and locale not in args.locales):
            continue
        findings = json.loads(path.read_text())
        by_key: dict[str, list[dict]] = collections.defaultdict(list)
        reasons = collections.Counter()
        for f in findings:
            why = eligible(locale, f, protected)
            if why is None and any(fnmatch.fnmatchcase(f"{locale}:{f['k']}", s) for s in skip):
                why = "descartada a mano"
            if why:
                reasons[why] += 1
                f["aplicada"] = False
                f["no_aplicada_por"] = why
            else:
                by_key[f["k"]].append(f)
        current = read_strings(strings_path(locale))
        infoplist = read_strings(strings_path(locale, "InfoPlist"))
        strings_changes, info_changes, plural_changes = {}, {}, {}
        for key, group in by_key.items():
            chosen = pick(group)
            for f in group:
                f["aplicada"] = f is chosen
                if f is not chosen:
                    f["no_aplicada_por"] = "otra propuesta para la misma clave"
                    reasons["otra propuesta para la misma clave"] += 1
            if key.startswith("InfoPlist:"):
                k = key.removeprefix("InfoPlist:")
                if infoplist.get(k) == chosen["actual"]:
                    info_changes[k] = chosen["propuesta"]
                else:
                    chosen["aplicada"], chosen["no_aplicada_por"] = False, "cambió desde la revisión"
            elif "#" in key:
                plural_changes[key] = chosen["propuesta"]
            elif current.get(key) == chosen["actual"]:
                strings_changes[key] = chosen["propuesta"]
            else:
                chosen["aplicada"] = False
                chosen["no_aplicada_por"] = "cambió desde la revisión" if key in current else "ya no está en .strings"
                reasons[chosen["no_aplicada_por"]] += 1
        n = len(strings_changes) + len(info_changes) + len(plural_changes)
        log[locale] = {"aplicadas": n, "motivos": dict(reasons)}
        if not args.dry_run:
            missing = write_values(strings_path(locale), strings_changes)
            if info_changes:
                write_values(strings_path(locale, "InfoPlist"), info_changes)
            apply_plurals(locale, plural_changes)
            assert not missing, missing
            path.write_text(json.dumps(findings, ensure_ascii=False, indent=1))
        print(f"{locale}: {n} aplicadas · {dict(reasons)}")
    if not args.dry_run:
        for alias, base in ALIASES.items():
            for name in ("Localizable.strings", "Localizable.stringsdict", "InfoPlist.strings"):
                src = RES / f"{base}.lproj" / name
                if src.exists():
                    shutil.copyfile(src, RES / f"{alias}.lproj" / name)
        (out_dir / "aplicado.json").write_text(json.dumps(log, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
