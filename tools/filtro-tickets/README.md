# Filtro de tickets con Haiku

Primera pasada barata sobre `tickets/backlog/`: candidatos a **ya resuelto** (contra el código de la rama
base) y a **duplicado**. No toca tickets ni el tablero; deja `informe.md` y `resultado.json` fuera del repo.
Decide la sesión o Frank, abriendo la evidencia que cita cada fila.

```bash
python3 -m venv ~/.venvs/yala-filtro-tickets && ~/.venvs/yala-filtro-tickets/bin/pip install anthropic   # una vez
git fetch origin
~/.venvs/yala-filtro-tickets/bin/python tools/filtro-tickets/filtro.py --salida ~/Claude/entregas/<sesión>/filtro-tickets --seco   # estima
~/.venvs/yala-filtro-tickets/bin/python tools/filtro-tickets/filtro.py --salida ~/Claude/entregas/<sesión>/filtro-tickets
```

Clave: `~/Secrets/yala-ai-bench/anthropic.key` (600; está en la Mini y en la Max). El script no la imprime.
Opciones y detalle: la cabecera de `filtro.py`.

## Lo que se midió el 2026-11-05 (lote T7)

Dos pasadas enteras sobre `origin/2.3`: 399 tickets y 150 pares cada una, ~4 min y **0,35-0,37 USD** por
pasada con `claude-haiku-5-5` (2,2 M tokens de entrada).

**Muestra revisada a mano (10 filas):**

| Fila | Veredicto del filtro | Revisado |
|---|---|---|
| `ipad-records-empty-detail-half-hidden-with-chat-open` | resuelto (pasada 1) | **Falso positivo**: el commit que lo «cerraba» era el que creó el ticket. Arreglado: los commits que solo tocan `tickets/`/`docs/` se marcan como «no es un arreglo»; en la pasada 2 ya no sale. |
| `invite-recovery-relaunches-for-a-mirror-it-never-uses` | resuelto, alta | **Acierto**: `requiresMirror(.inviteRecovery)` ya devuelve `false` en `WelcomeMirrorRelaunchLogic.swift`; el triage del 8-oct aún lo daba en `true`. |
| `invite-neutral-gate-reopens-the-welcome-without-recomputing-readiness` | resuelto (p1) / parcial (p2) | **Probable acierto**: el `defer { updateContentViewReadiness() }` del 13-oct recalcula tras el handler. Falta el XCUITest que lo mide. |
| `chat-creates-only-one-transaction-per-message` | resuelto, media | **Probable acierto**: el chat ya admite varios borradores y avisa del recorte (`chat.draft.overflowFormat`). |
| `migrate-group-can-create-a-group-with-an-owner-and-no-admin` | resuelto, media | **Plausible**: `migrate_group` está revocada y sin llamada en el cliente; confirmar en el backend. |
| `account-form-redesign`, `accounts-settings-list-redesign` | abierto, alta | **Correcto**: la evidencia citada (líneas exactas) es la del código. |
| tres «parcial» de adopt y Apple Pay | parcial, media | **Correctos**: evidencia y commits citados existen y dicen lo que la fila dice. |
| par `adopt-empty-backend-exit…` ~ `adopt-window-uploads…` | uno contiene al otro (p1) | **Razonable**: la salida por backend vacío es un caso de la ventana sin prueba de linaje. |

**Límites medidos:** con `effort: low` el veredicto **varía entre pasadas** (el par de arriba y un resuelto
salieron en una y no en la otra), y un tercio de los tickets queda en «no se sabe» porque la evidencia
automática no alcanza. Úsalo como lista de candidatos: unir dos pasadas encuentra más que una.
