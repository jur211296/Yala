---
description: Auditoría de consistencia del coverage-index — backlog, áreas stale, drift (código vs lastVerified), orphans
allowed-tools: Bash(python3 qa/qa-sync.py:*), Bash(bash qa/validate-coverage.sh:*), Bash(git log:*), Read, Edit, Glob, Grep
---

Completeness critic del SSOT de QA (`qa/coverage-index.json`). Ejecuta y reporta:

1. `bash qa/validate-coverage.sh` — estado del ratchet (gate). Si falla, mostrar el motivo.
2. `python3 qa/qa-sync.py` — reporte advisory:
   - **DRIFT**: áreas cuyo código se modificó DESPUÉS de su `lastVerified` → re-verificar / actualizar tests + `lastVerified`. Es la señal anti-drift principal.
   - **STALE**: áreas con `lastVerified` > 90 días.
   - **ORPHAN GLOBS**: `codeGlobs` que ya no matchean (código movido/borrado) → actualizar el índice.
   - **Backlog determinista**: áreas `deterministic` sin XCUITest, ordenadas por nº de escenarios (próximos targets de migración).

Presenta al usuario un resumen priorizado. Si lo pide:
- Ayuda a actualizar `lastVerified` / `codeGlobs` / `coverage` de las áreas en DRIFT/STALE/ORPHAN (editar solo `qa/coverage-index.json`).
- Ayuda a escribir el XCUITest faltante de un área del backlog (convenciones en CLAUDE.md sección "XCUITest"), y al cubrirla bajar `_meta.backlogBaseline`.

NUNCA modifiques código de la app — solo el índice y los tests. Puede correr on-demand o programado (`/schedule`).
