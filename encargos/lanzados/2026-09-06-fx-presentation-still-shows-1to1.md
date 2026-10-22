# Lo que se ve en pantalla deja de ser un 1:1 silencioso — marca de «aproximado»

## Contexto
Ticket: `tickets/backlog/fx-presentation-still-shows-1to1.md` (medium). Persistencia ya correcta (`fx-partial-rate-rows-silent-1to1`); ~34 llamadas de presentación aún usan `convert` a ciegas.

**Decisión Jürgen (2026-09-06) — no repreguntar:** número con marca de «aproximado» (≈ o rotulito), no omitir divisa ni dejarlo.

Cola medium autónoma (Frank): tras /cerrar-total, Frank lanza el siguiente (hero-estadisticas → welcome-privacy → panel-cuentas → reentry-killswitch → features → CI timeout).

## Que se pide
Implementar según ticket y AC:
- Propagar `convertChecked` / `RateQuality` por `CurrencyConverting` y ~28 inyecciones.
- Superficies que pintan totales (Panel, Tendencias, Estadísticas, saldos de Grupos) muestran marca cuando la calidad no es plena.
- Barrido de ~34 llamadas: ninguna `convert` a ciegas en presentación.
- Copy del rótulo en 16 `.lproj`; diseño de la marca en `/spec` si hace falta.
- **Review adversarial** antes del gate (cálculo financiero).
- Board + `docs/TICKETS.md` al día.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No omitir divisas como el widget (esa es otra decisión).
- No reabrir el fix de persistencia salvo residual documentado.

## Como se sabe que esta bien
- AC del ticket; review adversarial hecha; PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso de Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario; (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
