---
description: QA visual en el simulador — recorre los tickets en qa_, captura evidencia y actualiza su estado. Modo lote por defecto.
allowed-tools: Bash(bash qa/validate-coverage.sh:*), Bash(xcrun simctl:*), Bash(cp:*), Bash(date:*), Bash(git:*), Read, Write, Edit, Glob, Grep
argument-hint: "[nombre de ticket, o vacío para recorrer todos los qa_]"
---

QA visual de Yala. **Por defecto trabaja en LOTE**: una sola sesión drena varios tickets. Sin argumento, recorre todos los `qa_` del vault; con argumento, solo ese.

## Herramientas — en este orden

**1 · Simulador integrado de Claude Code** (`mcp__Claude_Code_iOS_Simulator__control`) — la opción por defecto para todo lo interactivo.

- `attach` **antes de compilar**, en cuanto sepas que vas a mirar la app: es barato, abre al instante si hay un simulador arrancado, y así el usuario ve el proceso entero.
- `screenshot` · `tap` · `swipe` · `text` · `button` · `open_url` para deep links.
- Las coordenadas van en puntos del dispositivo, origen arriba-izquierda.

**2 · XcodeBuildMCP** para lo que el integrado no cubre: `build_run_sim`, `install_app_sim`, `snapshot_ui` (árbol de accesibilidad con refs — úsalo cuando necesites identificadores, no coordenadas), `record_sim_video`.

Antes del primer build: `session_show_defaults`; si falta algo, `session_set_defaults` con scheme **Yala Dev** y el iPhone 17 Pro.

**`agent-device` no se usa.** Decisión del owner del 2026-07-07: roba el foreground, captura su propio runner en vez de la app y no acepta launch args.

## Antes de empezar

Comprueba el disco: `bash qa/scripts/disk-report.sh --guard`. Por debajo del umbral, el simulador falla al lanzar apps con errores que no mencionan el disco — no empieces una tanda de QA así.

## Flujo por ticket

1. **Lee el ticket** en `$VAULT/Bugs/qa_*.md` o `$VAULT/Backlog/qa_*.md`. Su sección de qa-notes o el guion de pasos dice qué reproducir. Si no hay guion, dedúcelo del commit que lo cerró.
2. **Prepara el estado**: `build_run_sim` con los launch args que haga falta (`-uitest-seed grupos`, `-uitest-skip-onboarding`, …; el catálogo vive en `UITestHooks`).
3. **Reproduce y captura.** Screenshot en cada paso que demuestre algo, no en cada tap.
4. **Veredicto PASS o FAIL**, con lo que viste — no con lo que esperabas ver.

## Al cerrar cada ticket

Evidencia al vault y estado actualizado:

```
VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/YalaWiki"
cp <screenshot> "$VAULT/Attachments/qa-<feature>-$(date +%Y%m%d-%H%M%S).png"
```

| Resultado | Renombrar | Frontmatter |
|---|---|---|
| PASS | `qa_x.md` → `ok_x.md` | `status: done` (Backlog) o `fixed` (Bugs) · `qa-status: passed` · `qa-date:` |
| FAIL | `qa_x.md` → `x.md` | `status: reopened` · `qa-status: failed` · `qa-notes:` sin comillas ni acentos |

Añade o actualiza la sección `## QA Visual` del ticket con fecha, veredicto, pasos y las capturas enlazadas.

Si el área tiene entrada en `qa/coverage-index.json`, actualiza su `lastVerified` y corre `bash qa/validate-coverage.sh`.

## Cierre del lote

Una tabla: ticket · veredicto · qué se vio. Y separa explícitamente **lo que no pudiste verificar aquí** — CloudKit multi-dispositivo, APNs, SIWA/Google, StoreKit real — a una lista de "requiere device físico". Eso no es un FAIL: es otra cola, y mezclarlas es lo que hace que se pierdan.

## Reglas

- **Nunca declares PASS por lo que dice el código.** Si no lo viste en pantalla, no está verificado.
- Un FAIL no se arregla dentro de `/qa`. Se documenta, se reabre el ticket y se sale.
- Nada de dispositivo físico salvo petición explícita del usuario.
- Si un escenario es determinista y lo estás repitiendo a mano, dilo: ese es un candidato a XCUITest, y bajar el `_meta.backlogBaseline` vale más que la captura.
