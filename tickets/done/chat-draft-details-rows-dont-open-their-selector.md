---
id: chat-draft-details-rows-dont-open-their-selector
status: done
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

## Resuelto (2026-10-27, sesión «yala-ia-detalles-selector»)

- **La hipótesis del lote 07 era falsa.** Con el XCUITest de oráculo, `e06bfff0c` (merge de #571, el lote 07 en 2.2) da
  verde. La bisección en primer padre `e06bfff0c..f23ddacad` da como primer rojo **#602** (`43daa3354`, lote decidido
  2.2 · 02, formulario sesión B). Ese merge sí compila con Xcode 27: el error de `ImportIntroSheet.swift` que salió en
  una primera medición era del build incremental.
- **La causa:** #602 añadió `.presentationBackground(.thickMaterial)` (estilo) a `SelectorSheetSizing.mediumFirst`, el
  tamaño de los selectores de categoría, cuenta y etiquetas. Con ese modificador, una hoja pedida desde «Detalles» —una
  hoja que ya está sobre la hoja del chat— no llega a presentarse. Fecha no lo lleva: en un arranque limpio abre bien
  (medido); lo que se vio a mano era tocar Fecha después de otro campo, con la presentación anterior atascada.
  Experimento: sin el modificador, los cuatro abren.
- **El arreglo:** el mismo material como vista, `.presentationBackground { Rectangle().fill(.thickMaterial) }`. Los
  cuatro abren y la hoja a media altura de Nuevo registro se ve igual (diferencia ≤ 8/255 en la cabecera, sin monto
  legible detrás: L2-22 se mantiene).
- **Tests:** tres casos nuevos en `ChatMessagingLayoutUITests` (categoría, fecha, etiquetas) junto al de cuenta. En la
  base, 3 rojos (categoría, cuenta, etiquetas) y fecha verde; con el arreglo, 4 verdes. La trampa queda en
  `.claude/rules/swiftui-ds.md`.
