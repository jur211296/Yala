# Siri y Atajos enseñan las preguntas nuevas, y Spotlight muestra tus cuentas y movimientos

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: medium.
Slug: `siri-atajos-spotlight` · Sesión cola **S20** · al cerrar → **S21**.

## Contexto · cards del lote
- UX 2.2 · L15-4 · «Siri y Atajos» no enseña las preguntas nuevas («Cuánto gasté», «Mi saldo»)
- Siri con IA: ¿tus cuentas y movimientos en Spotlight? ¿Las preguntas a Siri, gratis o Pro?

## Briefs per-card (lee y cumple cada uno)
- `~/Claude/tmp-frank/siri-atajos-preguntas-nuevas-filas-bthx.md`
- `~/Claude/tmp-frank/siri-spotlight-cuentas-movimientos-ste6.md`

## Qué se pide
1. Lee y cumple ambos briefs: filas nuevas en «Siri y Atajos» (opción A) + Spotlight cuentas/movimientos (opción C).
2. Un PR a 2.2; respeta bloqueo/borrado/ocultos en indexación.

Mueve las cards a «in progress» con `--agente frank` al empezar; al cerrar, a in qa / done según el cierre de cada una.

## Qué NO tocar
- marketing/ y Web/ (Lola).
- Otras sesiones de la cola (no las lances).
- No desactivar tests ni saltarte el gate.
- Lo específico de cada brief per-card.

## Cómo se sabe que está bien
Cada card cumple su hechaCuando; suite relevante verde; PR a 2.2 en auto-merge; `/cerrar-total`.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.
- marketing/ y Web/ = Lola. No relances otras sesiones Yala.


## Paso 0 (Frank, 2026-10-28 — auto-contestado, MODO cola)

**Parte A · «Siri y Atajos» (bthx).** Dos filas al final de «Otros atajos» con el molde de las cuatro: nombre de Atajos
(`shortcut.spending.shortTitle` / `shortcut.balance.shortTitle`, ya traducidos), descripción y frase. Frases: «Cuánto
gasté en Yala» y «Mi saldo en Yala» y su traducción entrenada en cada idioma (`AppShortcuts.xcstrings`), fijadas por los
dos tests de paridad de frases. Sin insignia Pro: son gratis (decisión de Jürgen del 2026-10-18).

**Parte B · Spotlight (ste6, opción C).**
- **Qué se indexa**: las tarjetas de cuenta que enseña el Panel (la foto de Siri: sin archivadas, excluidas ni de
  sistema; nombre y divisas, **sin saldo**: cambia a diario y se quedaría viejo en el índice) y los movimientos que
  enseña Registros sin filtros (fuera los de cuentas excluidas de estadísticas, los de grupos si el ajuste los oculta,
  los que esperan su «Deshacer»; en «Solo gastos», solo gastos). Con importe, categoría, cuenta y fecha.
- **Asumido**: fuera transferencias y ajustes de saldo (dos filas por transferencia; un ajuste no es algo que se
  busque). Con la vista de solo grupos, el índice se vacía.
- **Bloqueo**: índice con protección `complete` (no se lee con el iPhone bloqueado); con «Requerir Face ID» en el icono,
  iOS oculta el contenido de la app en búsquedas (documentado por Apple, no medible en el simulador).
- **Borrado**: el índice se vacía en el mismo embudo que la foto de Siri y los widgets (`WidgetDataCache.clearCache`:
  cierre de sesión, «Vaciar datos», purgas) y se reconcilia con diff en cada `updateCache` y al volver a primer plano
  (lo que llega por sincronización). Con un borrado armado no se reindexa.
- **Tocar un resultado** abre la ficha de la cuenta (`accounts/<id>`) o el registro (`records/<syncID>`).
- Preguntas a Siri: siguen gratis, sin cambio de código.
- Fuera: «esta cuenta» en pantalla, búsqueda dentro de la app y donaciones (no los pidió el brief).
