---
esfuerzo: medium
---
# Multi-divisa (A1): spec con las decisiones de Jürgen y tickets de las cuatro entregas

**Card:** `tablero-una-cuenta-con-mas-de-una-divisa-la-tarj-mn0q` · **Spec:** `docs/multi-currency-accounts-impact-2026-10.md` (en 2.1 desde el PR #402) · **Ticket raíz:** `tickets/backlog/multi-currency-accounts.md`

## Decisiones de Jürgen (sección 5 cerrada)
- 1 y 2: **opción A, variante A1** (enlace a la cuenta principal, sin entidad nueva). Aceptada el 9-oct a las 16:19 Lima.
- 3: **cualquier tipo de cuenta**, ofrecido primero en tarjetas de crédito. (10-oct, 05:55 Lima)
- 4: **sí** se pueden vincular dos cuentas que ya tienen movimientos; vincular no toca el historial. (10-oct, 05:55)
- 5: las líneas extra **no** cuentan para el límite Free: la tarjeta cuenta una vez. (10-oct, 05:55)
- 6: al registrar un gasto **se elige la tarjeta y la divisa del importe decide la línea**; el selector enseña las líneas anidadas. (10-oct, 05:55)

## Que se pide (solo docs y tickets: no implementes nada)
1. Arranca sobre `origin/2.1`.
2. Actualiza la spec: sección 5 con las respuestas y la fecha; la sección 4/6 deja de decir «propuestas» y queda como plan decidido; ajusta lo que cambie por las respuestas (p. ej. tipos de cuenta en el formulario, vincular con historial, límite Free, selector).
3. Abre los cuatro tickets de la sección 6 en `tickets/backlog/`, cada uno con alcance, ficheros implicados, criterio de hecho medible, dependencias y prioridad (la 1 va sola y antes que nada; 2, 3 y 4 dependen de la 1):
   - `multi-currency-accounts-1-model-and-sync` (modelo, sync, esquema, DDL y deploy de `CD_Account`; sin UI; review adversarial).
   - `multi-currency-accounts-2-card-view`.
   - `multi-currency-accounts-3-pickers-and-capture`.
   - `multi-currency-accounts-4-reports-and-export`.
   Enlázalos desde `tickets/backlog/multi-currency-accounts.md` y desde la spec, y actualiza `docs/TICKETS.md`.
4. Si la entrega 1 depende de `personal-cloudkit-schema-snapshot-misses-optional-fields` (el esquema de iCloud personal), dilo en su ticket como bloqueo.
5. Cada ticket nuevo con su card: mira primero con `tablero listar --proyecto Yala --todas` que no exista y créala con `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --version 2.2 --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url del PR>"`. Las 4 cards de entregas van con `--version 2.2` (ADR-069). SIN --fecha (la fecha es opcional desde el ADR-068; no pongas fecha de relleno). Lista las cards (título e id) en el aviso de cierre.
6. Rebase al final, sin esperar a nadie: justo antes de abrir el PR, `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí cualquier conflicto (strict=false; en `docs/TICKETS.md` conserva las dos versiones y corrige el recuento).
7. Cierre: `/cerrar-total` autónomo (PR solo docs a 2.1 con auto-merge, limpieza). Card mn0q a «done» (frank) con los ids de las cuatro cards nuevas en la nota.

## Carga de la Mini (OBLIGATORIO)
No hace falta Xcode ni simulador. Si por algo lo necesitas: `nice -n 10 xcodebuild -jobs 2 ...`, nunca dos builds o tests a la vez, espera a que la carga de 1 minuto baje de 8 (`while [ $(sysctl -n vm.loadavg | awk '{print int($2)}') -ge 8 ]; do sleep 30; done`), sin pasar xcodebuild por `| head` y con los `-only-testing:` en un array.

## Paso 0

Decisiones resueltas antes de escribir (sesión lanzada, sin nadie delante; lo asumido va marcado).

1. **Dónde se entrega.** Worktree → rama `encargo/…` + PR a `2.1` con auto-merge. Diff solo en `docs/`,
   `tickets/` y `encargos/`: sin nada que compilar, el gate se queda en la validación del índice.
2. **Bloqueo de la entrega 1.** Sí depende de `personal-cloudkit-schema-snapshot-misses-optional-fields`:
   la entrega 1 añade un campo opcional a `CD_Account` y se apoya en el snapshot `.ckdb` y en el deploy a
   Production; ese ticket dice que el snapshot no es fiel. Se anota como **bloqueo** en el ticket 1
   (`blocked-by`), y el ticket queda en `backlog` porque el encargo pide abrirlo ahí.
3. **Prioridades** (asumido). Entrega 1 `high`: es el prerrequisito de las otras tres y toca sync.
   Entregas 2-4 `medium`, la del ticket raíz.
4. **Tipos de cuenta (decisión 3).** «Cualquier tipo, ofrecido primero en tarjetas»: se traduce en que la
   acción del formulario aparece destacada en tarjetas de crédito y disponible en el resto. El modelo no
   filtra por tipo.
5. **El ticket raíz** sigue en `backlog` como épica: sale de «espera la decisión de Jürgen» y pasa a
   índice de las cuatro entregas.
6. **Cards.** Una por entrega, `--version 2.2`, sin `--fecha`, con el enlace al PR una vez abierto.
