"""Lectura y escritura de los catálogos de Yala para la revisión de traducciones.

Los `.strings` del repo son de una línea por clave (`"clave" = "valor";`), así que se leen y se
reescriben línea a línea sin tocar comentarios ni el orden. Los `.stringsdict` se leen con plistlib.
"""
from __future__ import annotations

import fnmatch
import plistlib
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
RES = REPO / "Yala" / "Resources"

# Idioma de referencia: es la fuente del significado. `en` es la segunda referencia.
REFERENCE = "es-419"
BASES = ["es-419", "en", "de", "fr", "it", "nl", "pl", "pt-BR", "pt-PT", "ja", "zh-Hans"]
# Variantes con respaldo materializado del padre: el LLM solo mira sus overrides.
VARIANTS = {"en-GB": "en", "es-ES": "es-419", "es-AR": "es-419"}
# Alias catch-all: copia idéntica de su base (lo exige LocalizationParityTests).
ALIASES = {"es": "es-419", "pt": "pt-BR"}
# pt-PT tiene padre (pt-BR) pero se revisa entero: su respaldo es el pt-BR viejo.
PARENT_OF = {"pt-PT": "pt-BR", **VARIANTS}

LINE_RE = re.compile(r'^(\s*)"((?:[^"\\]|\\.)*)"(\s*=\s*)"((?:[^"\\]|\\.)*)"(\s*;.*)$')
# Los formatos que usa Yala: %@, %d, %ld, %lld, %1$@, %.0f, %.2f, %i, %u, %%. Sin flags a propósito:
# con ellos «32% hoch» casaba «% ho» como placeholder.
PLACEHOLDER_RE = re.compile(r"%(?:\d+\$)?(?:\.\d+)?(?:ll|l|h)?[@dDiuUfxsc%]")


def strings_path(locale: str, name: str = "Localizable") -> Path:
    return RES / f"{locale}.lproj" / f"{name}.strings"


def read_strings(path: Path) -> dict[str, str]:
    """clave → valor ESCAPADO tal cual está en el fichero (no se desescapa: se compara y se escribe igual)."""
    out: dict[str, str] = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8").split("\n"):
        m = LINE_RE.match(line)
        if m:
            out[m.group(2)] = m.group(4)
    return out


def read_strings_text(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in text.split("\n"):
        m = LINE_RE.match(line)
        if m:
            out[m.group(2)] = m.group(4)
    return out


def read_plurals(locale: str) -> dict[str, dict[str, str]]:
    """clave → {forma: texto} de la variable principal de cada plural del `.stringsdict`."""
    path = RES / f"{locale}.lproj" / "Localizable.stringsdict"
    if not path.exists():
        return {}
    data = plistlib.loads(path.read_bytes())
    out: dict[str, dict[str, str]] = {}
    for key, entry in data.items():
        forms: dict[str, str] = {}
        for var, spec in entry.items():
            if var == "NSStringLocalizedFormatKey" or not isinstance(spec, dict):
                continue
            for form in ("zero", "one", "two", "few", "many", "other"):
                if form in spec:
                    forms[f"{var}.{form}"] = spec[form]
        fmt = entry.get("NSStringLocalizedFormatKey", "")
        if fmt and fmt.strip() not in ("%#@count@", "%#@value@") and not re.fullmatch(r"%#@\w+@", fmt.strip()):
            forms["format"] = fmt
        out[key] = forms
    return out


def write_values(path: Path, changes: dict[str, str]) -> list[str]:
    """Sustituye en su sitio el valor de cada clave. Devuelve las claves que no encontró."""
    lines = path.read_text(encoding="utf-8").split("\n")
    pending = dict(changes)
    for i, line in enumerate(lines):
        m = LINE_RE.match(line)
        if m and m.group(2) in pending:
            lines[i] = f'{m.group(1)}"{m.group(2)}"{m.group(3)}"{pending.pop(m.group(2))}"{m.group(5)}'
    path.write_text("\n".join(lines), encoding="utf-8")
    return sorted(pending)


def placeholders(value: str) -> list[str]:
    """Placeholders sin el índice posicional, ordenados (el orden puede cambiar entre idiomas)."""
    found = [re.sub(r"^%\d+\$", "%", p) for p in PLACEHOLDER_RE.findall(value) if p != "%%"]
    return sorted(found)


def load_protected() -> list[str]:
    path = Path(__file__).with_name("claves-protegidas.txt")
    pats = []
    for line in path.read_text(encoding="utf-8").split("\n"):
        line = line.split("#", 1)[0].strip()
        if line:
            pats.append(line)
    return pats


def is_protected(key: str, pats: list[str]) -> bool:
    return any(fnmatch.fnmatchcase(key, p) for p in pats)
