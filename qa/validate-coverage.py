#!/usr/bin/env python3
"""
Validador del coverage-index.json — SSOT de QA de Yala.

Se usa en: git pre-push hook, CI (qa.yml) y /qa-sync.

Reglas DURAS (exit 1 — bloquean):
  - JSON valido y estructura por area (area, codeGlobs, scenarioIDs, classification, coverage, lastVerified).
  - classification en {deterministic, agentic, manual}.
  - sin areas duplicadas.
  - RATCHET ANTI-DRIFT: el backlog de areas 'deterministic' SIN cobertura XCUITest
    no puede CRECER respecto a _meta.backlogBaseline. Anadir un area determinista
    sin test (o borrar un test existente) hace crecer el backlog -> FAIL.
    -> Escribe el XCUITest, o baja conscientemente backlogBaseline.

Reglas BLANDAS (warn — no bloquean):
  - area sin scenarioIDs / sin lastVerified.
  - codeGlobs que no matchean ningun archivo (posible refactor que dejo el index stale).
  - backlog bajo el baseline -> recordatorio de actualizar backlogBaseline (ratchet up).
"""
import json
import os
import sys
import glob

QA_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(QA_DIR)
INDEX = os.path.join(QA_DIR, "coverage-index.json")

VALID_CLASS = {"deterministic", "agentic", "manual"}

errors = []
warnings = []

try:
    with open(INDEX, encoding="utf-8") as f:
        data = json.load(f)
except FileNotFoundError:
    print(f"FAIL  no existe {INDEX}")
    sys.exit(1)
except json.JSONDecodeError as e:
    print(f"FAIL  JSON invalido en coverage-index.json: {e}")
    sys.exit(1)

meta = data.get("_meta", {})
areas = data.get("areas", [])

seen = set()
for a in areas:
    name = a.get("area")
    if not name:
        errors.append("area sin nombre")
        continue
    if name in seen:
        errors.append(f"area duplicada: {name}")
    seen.add(name)

    cls = a.get("classification")
    if cls not in VALID_CLASS:
        errors.append(f"{name}: classification invalida '{cls}'")
    if not a.get("codeGlobs"):
        errors.append(f"{name}: codeGlobs vacio")
    if "coverage" not in a:
        errors.append(f"{name}: falta campo coverage")
    if not a.get("scenarioIDs"):
        warnings.append(f"{name}: sin scenarioIDs")
    if not a.get("lastVerified"):
        warnings.append(f"{name}: sin lastVerified")

    for g in a.get("codeGlobs", []):
        if not glob.glob(os.path.join(ROOT, g), recursive=True):
            warnings.append(f"{name}: glob sin match (index stale?) '{g}'")

# --- RATCHET ---
backlog = [
    a["area"] for a in areas
    if a.get("classification") == "deterministic"
    and not str(a.get("coverage", "")).startswith("xcuitest:")
]
baseline = meta.get("backlogBaseline")

det_total = sum(1 for a in areas if a.get("classification") == "deterministic")
det_covered = det_total - len(backlog)
print(f"Areas: {len(areas)}  |  deterministic: {det_total}  cubiertas(XCUITest): {det_covered}  backlog: {len(backlog)}")

if baseline is None:
    warnings.append("_meta.backlogBaseline ausente — no se puede aplicar el ratchet anti-drift")
elif len(backlog) > baseline:
    errors.append(
        f"RATCHET: el backlog determinista crecio {baseline} -> {len(backlog)}. "
        f"Anadiste un area 'deterministic' sin XCUITest o borraste un test. "
        f"Escribe el test o baja conscientemente _meta.backlogBaseline. "
        f"Backlog actual: {sorted(backlog)}"
    )
elif len(backlog) < baseline:
    warnings.append(
        f"RATCHET ↑: backlog bajo {baseline} -> {len(backlog)}. "
        f"Actualiza _meta.backlogBaseline a {len(backlog)} para fijar el avance."
    )

for w in warnings:
    print(f"  WARN  {w}")
for e in errors:
    print(f"  FAIL  {e}")

print("RESULT:", "FAIL" if errors else "OK")
sys.exit(1 if errors else 0)
