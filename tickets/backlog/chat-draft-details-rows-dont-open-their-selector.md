---
id: chat-draft-details-rows-dont-open-their-selector
status: backlog
priority: high
area: yala-ia
created: 2026-10-27
updated: 2026-10-27
source: "ui-suite-2-2-five-tests-red-on-the-base: ChatMessagingLayoutUITests/test_draftDetails_opensSheet_withTheNewRecordAccountSelector"
---

# En Yala IA, «Detalles» de un registro propuesto no abre ningún selector

## Qué ve el usuario

En el chat de Yala IA, con un registro propuesto, «Detalles» abre la hoja «Registro propuesto». Tocar **Categoría,
Cuenta, Fecha o Etiquetas** no hace nada: el selector no sale. Los chips de la tarjeta del chat (fuera de la hoja) sí
abren el suyo. Así que desde «Detalles» no se puede cambiar la cuenta ni la categoría del borrador.

## Lo medido (2026-10-27, iPhone 17 Pro, iOS 27.0, árbol de `origin/2.2` @ 279d1510b)

- **Reproduce a mano**, abriendo el chat desde Registros y desde el Panel, con `-uitest -uitest-reset
  -uitest-skip-onboarding -uitest-pro -uitest-seed minimal -uitest-ai-chat-ready -uitest-chat-suggestions
  -uitest-chat-draft`. No es cosa del test.
- **El toque llega y SwiftUI construye la hoja**: con sondas `print` en `ChatDraftDetailSheet` (retiradas), el botón de
  la fila pone `activeField = .account`, el `onChange` lo ve y el cierre de `.sheet(item: $activeField)` se evalúa
  («sheet content account»). Con «Fecha» después, lo mismo.
- **UIKit nunca la recibe**: la cadena de `presentedViewController` de la ventana se queda en dos niveles (el chat y la
  hoja de detalles, 402×464), sin un tercero. No hay ningún aviso en la consola de la app ni en `log stream`.
- **No lo arregla** colgar el `.sheet(item:)` dentro de la `NavigationStack` en vez de fuera (probado: el XCUITest sigue rojo).
- **Ventana de la regresión**: la nocturna de `qa.yml` lo da verde el 19, 20 y 21-oct (último verde: `df498b7cc`, merge
  de #580) y rojo el 23, 25 y 26-oct (primer rojo medido: `43daa3354`, merge de #602; el 22-oct no corrió ese caso).
  Entre los dos entra el merge del lote decidido 2.2 · 07 (Yala IA, `221791927`), que trae los commits del chat del
  15 al 22-oct; es el primer sospechoso, **sin bisecar**.

## Sin medir

La línea que lo rompe. El siguiente paso es bisecar entre `df498b7cc` y `43daa3354` (81 commits en primer padre)
con el XCUITest de arriba como oráculo, empezando por `221791927^1` contra `221791927`.

## Hecho cuando

Los cuatro campos de «Detalles» abren su selector y `test_draftDetails_opensSheet_withTheNewRecordAccountSelector` está
verde. Antes de publicar 2.2: es una regresión de 2.2 que no está en 2.1.
