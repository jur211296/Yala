---
description: QA visual en el simulador — recorre los tickets en tickets/qa/, captura evidencia y actualiza su estado. Modo lote por defecto.
allowed-tools: Bash(bash qa/validate-coverage.sh:*), Bash(bash qa/scripts/sim-lock.sh:*), Bash(cut:*), Bash(kill:*), Bash(xcrun simctl:*), Bash(cp:*), Bash(date:*), Bash(git:*), Read, Write, Edit, Glob, Grep
argument-hint: "[nombre de ticket, o vacío para recorrer todos los de tickets/qa/]"
---

QA visual de Yala. **Por defecto trabaja en LOTE**: una sola sesión drena varios tickets. Sin argumento, recorre todos los `.md` de `tickets/qa/`; con argumento, solo ese.

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

## Turno del simulador — antes del primer build

El simulador es uno y lo comparten todas las sesiones. Un `build_run_sim` o un `install_app_sim` instala
sobre el mismo bundle id que el `/gate` de otra sesión está probando: **le tumbas la corrida y su rojo
parece un bug del producto**. Y ninguna firma del centinela (`sim-libre.sh`) ve un install, así que nadie
te avisa. Por eso el `/qa` **pide turno y lo sostiene** toda la tanda:

1. Toma el turno en segundo plano (Bash con `run_in_background`), con un tope de 2 h por si la sesión
   muere sin soltarlo:
   ```bash
   bash qa/scripts/sim-lock.sh -- sleep 7200
   ```
   Si otra sesión lo tiene, **espera** y dice quién. No empieces a instalar mientras espera.
2. Comprueba que es tuyo: `bash qa/scripts/sim-lock.sh --estado` → `TOMADO`, con `sleep 7200`, tu
   directorio y el pid de ese proceso en segundo plano.
3. Si dentro de la tanda corres un XCUITest conductor, pasa por la misma cola **reentrando** en tu turno
   (si no, esperaría a tu propio `sleep` para siempre):
   ```bash
   YALA_SIM_LOCK_HELD=$(cut -f1 ~/Library/Caches/Yala/simulador.lock) \
     bash qa/scripts/sim-lock.sh -- xcodebuild … test …
   ```
   Solo con tu propio turno: el primer campo del lockfile es el token de quien lo tiene ahora.
4. Al acabar —o si la tanda se corta— **suéltalo**: `kill <pid del paso 1>` y `--estado` dice `OK`.
   Si la tanda pasa de 2 h, vuelve al paso 1.

`/barrido-qa` y el device QA visual de las recetas de traducción (`qa/prompts/`) piden turno igual.

## Flujo por ticket

1. **Lee el ticket** en `tickets/qa/*.md` (índice: `docs/TICKETS.md`). Su sección de qa-notes o el guion de pasos dice qué reproducir. Si no hay guion, dedúcelo del commit que lo cerró.
2. **Prepara el estado**: `build_run_sim` con los launch args que haga falta (`-uitest-seed grupos`, `-uitest-skip-onboarding`, …; el catálogo vive en `UITestHooks`).
3. **Reproduce y captura.** Screenshot en cada paso que demuestre algo, no en cada tap.
4. **Veredicto PASS o FAIL**, con lo que viste — no con lo que esperabas ver.

## Al cerrar cada ticket

Evidencia junto al ticket (no Obsidian) y estado actualizado:

```
cp <screenshot> "tickets/qa/qa-<feature>-$(date +%Y%m%d-%H%M%S).png"
```

| Resultado | Mover | Frontmatter |
|---|---|---|
| PASS | `tickets/qa/x.md` → `tickets/done/x.md` | `status: done` · `qa-status: passed` · `qa-date:` |
| FAIL | `tickets/qa/x.md` → `tickets/in-progress/x.md` | `status: in-progress` · `qa-status: failed` · `qa-notes:` sin comillas ni acentos |

**No declares PASS si no lo viste en pantalla.** No cierres un ticket por inferencia.

Añade o actualiza la sección `## QA Visual` del ticket con fecha, veredicto, pasos y las capturas enlazadas. Actualiza `docs/TICKETS.md` si moviste el archivo.

Si el área tiene entrada en `qa/coverage-index.json`, actualiza su `lastVerified` y corre `bash qa/validate-coverage.sh`.

## Cierre del lote

Suelta el turno del simulador (paso 4 de «Turno del simulador»).


Una tabla: ticket · veredicto · qué se vio. Y separa explícitamente **lo que no pudiste verificar aquí** — CloudKit multi-dispositivo, APNs, SIWA/Google, StoreKit real — a una lista de "requiere device físico". Eso no es un FAIL: es otra cola, y mezclarlas es lo que hace que se pierdan.

## Reglas

- **Nunca declares PASS por lo que dice el código.** Si no lo viste en pantalla, no está verificado.
- Un FAIL no se arregla dentro de `/qa`. Se documenta, se reabre el ticket y se sale.
- Nada de dispositivo físico salvo petición explícita del usuario.
- Si un escenario es determinista y lo estás repitiendo a mano, dilo: ese es un candidato a XCUITest, y bajar el `_meta.backlogBaseline` vale más que la captura.
