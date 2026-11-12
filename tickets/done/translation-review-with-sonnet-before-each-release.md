---
id: translation-review-with-sonnet-before-each-release
status: done
priority: low
area: l10n, qa
created: 2026-10-25
updated: 2026-10-25
source: card `tablero-revision-de-traducciones-con-sonnet-ante-681y` (lote 12.4)
---

# Revisión de traducciones con Sonnet antes de cada release (16 idiomas)

## Qué se hizo

`qa/l10n-review/` revisa los catálogos contra el español de referencia y deja un informe por idioma; cómo correrlo y
qué aplica está en su `README.md`, y la línea de «Antes de cerrar una release» del `CLAUDE.md` lo enlaza.

- Va con el CLI de Claude Code y Sonnet, con la suscripción: sin clave ni gasto de API. La API queda como opción
  (`--backend api`, `ANTHROPIC_API_KEY`), sin usar.
- **Primera corrida, catálogo entero, 2026-10-25**: 439 trozos en ~25 min; ~4.500 hallazgos. Se aplicaron 1.956 en la
  primera pasada y 26 en la segunda (que revisa solo lo cambiado), más 49 textos de ayuda y 53 de pt-PT en pasadas
  dirigidas. Informe: `qa/l10n-review/informes/2026-10-25/` (`resumen.md`, `aplicado.json` y un JSON por idioma con
  el motivo de lo no aplicado).
- No se aplicó: terminología (ticket `l10n-terminology-follows-the-tab-names`), gravedad baja, lo que toca el nombre
  del asistente, las claves protegidas y las descartadas a mano (`descartadas.txt`).
