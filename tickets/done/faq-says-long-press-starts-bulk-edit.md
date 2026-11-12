---
id: faq-says-long-press-starts-bulk-edit
status: done
priority: low
area: "copy, records, help"
created: 2026-09-30
updated: 2026-10-14
source: "hallazgo de la fase 3 iPad (ipad-keyboard-shortcuts-pointer-context-menus-and-drop), 2026-09-30"
---

# El FAQ dice que mantener pulsado un registro entra en la edición masiva

## Qué pasa

La respuesta de ayuda `faq.changeCategory.a` dice: «Si quieres cambiar varios a la vez, usa la edición masiva:
mantén presionado un registro y selecciona los que quieras modificar».

Medido el 2026-09-30: en `RecordRowView` no hay ningún gesto de pulsación larga. El modo selección se abre desde el
menú «⋯» de Registros (`RecordsOverflowMenu`, `enterSelectionMode()`). Y desde la fase 3, mantener pulsado un
registro abre su **menú contextual** (Editar, Duplicar, Cambiar categoría, Eliminar).

## Qué hay que hacer

Reescribir esa respuesta en los 16 idiomas: el cambio de categoría de uno se hace también desde la pulsación larga
(«Cambiar categoría»), y el de varios, desde «⋯ › Seleccionar». Leer `docs/planning/BRAND-VOICE.md` antes.
No se tocó en la fase 3 porque es copy de ayuda, fuera de su alcance.

## Medido en 2.1 (triage 2026-10-08)

- `faq.changeCategory.a` sigue diciendo «mantén presionado un registro y selecciona los que quieras modificar» (`es.lproj`, línea ~2426; igual en `en.lproj`).
- La selección múltiple sigue entrando solo por `RecordsOverflowMenu` → `enterSelectionMode()`; no hay `onLongPressGesture` en `Yala/App/Views/Records/`.

Triage 2026-10-08: abierto · low → low · el texto de ayuda sigue describiendo un gesto que no existe; molesta, no toca datos.

## Hecho (2026-10-14, auditoría UX 2.2 · lote 8, B7)

Nueva respuesta en los 16 idiomas (es-AR con voseo): abrir el registro y «Editar», o mantenerlo pulsado y «Cambiar
categoría»; varios a la vez, con ··· › «Seleccionar», marcarlos y el lápiz. También desaparece «toca la categoría»
(en el detalle no hace nada). Visto en el simulador: `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-8-registros/capturas/B7-despues-faq.png`.
Test: `RecordsAuditLote8StringsTests.faq_describesTheRealGestures`. PR #499.
