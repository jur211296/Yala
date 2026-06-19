#!/usr/bin/env python3
"""
qa-sync — completeness critic sobre qa/coverage-index.json.

Complementa al validador (validate-coverage.py, que es el GATE): este es un
REPORTE advisory que detecta lo que el ratchet no ve:
  - backlog determinista (áreas sin XCUITest) — la hoja de ruta de migración.
  - áreas STALE (lastVerified > STALE_DAYS).
  - DRIFT: código de un área modificado DESPUÉS de su lastVerified (señal de que
    se tocó algo sin re-verificar su cobertura — el corazón anti-drift).
  - orphan globs (código movido/borrado → index stale).

Exit 0 siempre (es reporte, no gate). El gate es validate-coverage.py.
"""
import json
import os
import glob
import subprocess
import datetime

QA_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(QA_DIR)
INDEX = os.path.join(QA_DIR, "coverage-index.json")
STALE_DAYS = 90

today = datetime.date.today()


def age_days(dstr):
    try:
        return (today - datetime.date.fromisoformat(dstr)).days
    except Exception:
        return None


def git_last_change(globs):
    """Fecha (YYYY-MM-DD) del último commit que tocó cualquiera de los globs."""
    paths = [g[:-3] if g.endswith("/**") else g for g in globs]
    if not paths:
        return None
    try:
        out = subprocess.run(
            ["git", "-C", ROOT, "log", "-1", "--format=%cs", "--"] + paths,
            capture_output=True, text=True, timeout=20,
        )
        return out.stdout.strip() or None
    except Exception:
        return None


def main():
    data = json.load(open(INDEX, encoding="utf-8"))
    areas = data.get("areas", [])

    backlog, stale, orphans, drift, agentic_backlog = [], [], [], [], []
    for a in areas:
        name = a.get("area", "?")
        cls = a.get("classification")
        cov = str(a.get("coverage", ""))
        for g in a.get("codeGlobs", []):
            if not glob.glob(os.path.join(ROOT, g), recursive=True):
                orphans.append((name, g))
        if cls == "deterministic" and not cov.startswith("xcuitest:"):
            backlog.append((name, len(a.get("scenarioIDs", []))))
        if cls == "agentic" and not cov.startswith("device-qa"):
            agentic_backlog.append((name, len(a.get("scenarioIDs", []))))
        lv = a.get("lastVerified")
        age = age_days(lv) if lv else None
        if age is not None and age > STALE_DAYS:
            stale.append((name, age))
        last = git_last_change(a.get("codeGlobs", []))
        if last and lv:
            try:
                if datetime.date.fromisoformat(last) > datetime.date.fromisoformat(lv):
                    drift.append((name, lv, last))
            except Exception:
                pass

    det = sum(1 for a in areas if a.get("classification") == "deterministic")
    covered = det - len([b for b in backlog])
    ag = sum(1 for a in areas if a.get("classification") == "agentic")
    ag_covered = ag - len(agentic_backlog)
    print("== qa-sync: completeness critic ==")
    print(f"Áreas: {len(areas)} | deterministic: {det} cubiertas(XCUITest): {covered} backlog: {len(backlog)}")
    print(f"agentic: {ag} cubiertas(device-qa): {ag_covered} backlog: {len(agentic_backlog)}")
    print(f"Stale (>{STALE_DAYS}d): {len(stale)} | Drift (código>lastVerified): {len(drift)} | Orphan globs: {len(orphans)}")

    if drift:
        print("\n-- DRIFT (re-verificar: el código cambió tras el último lastVerified) --")
        for name, lv, last in sorted(drift, key=lambda x: x[2], reverse=True):
            print(f"  ! {name}: lastVerified={lv} < últimoCambio={last}")
    if stale:
        print("\n-- STALE --")
        for name, age in sorted(stale, key=lambda x: -x[1]):
            print(f"  · {name}: {age}d")
    if orphans:
        print("\n-- ORPHAN GLOBS (index stale, código movido/borrado) --")
        for name, g in orphans:
            print(f"  · {name}: {g}")

    if backlog:
        print("\n-- Próximos targets de migración (deterministic sin XCUITest, por nº escenarios) --")
        for name, n in sorted(backlog, key=lambda x: -x[1])[:8]:
            print(f"  → {name} ({n} escenarios)")

    if agentic_backlog:
        print("\n-- Backlog agentic (sin device-qa — cubrir con /device-qa, por nº escenarios) --")
        for name, n in sorted(agentic_backlog, key=lambda x: -x[1]):
            print(f"  → {name} ({n} escenarios)")

    print("\n(Reporte advisory. El gate es validate-coverage.py / git pre-push / CI.)")


if __name__ == "__main__":
    main()
