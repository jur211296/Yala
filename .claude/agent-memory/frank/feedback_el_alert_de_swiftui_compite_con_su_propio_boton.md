---
name: el-alert-de-swiftui-compite-con-su-propio-boton
description: Un `.alert` con binding derivado cuyo `set` hace trabajo compite con la acción del botón que lo cerró — y si la acción es async, pierde. Cazado el 9-sep por dos lentes a la vez.
metadata:
  type: feedback
---

**El `set` de un binding derivado de `.alert` corre al pulsar CUALQUIER botón, no solo al cancelar.
Si ese `set` hace trabajo y la acción del botón es `async`, el `set` gana.**

**Why:** en iOS un alert **no tiene gesto de descarte** — se cierra pulsando un botón. SwiftUI
escribe `false` en su `isPresented` en los dos casos. El 2026-09-09 escribí
`set: { if !$0 { viewModel.cancelCurrencyConversion() } }` con el comentario «cubre el gesto de
descartar»: ese gesto no existe, y lo que el setter cubría de verdad era también el botón
Convertir. Como la acción del botón solo **encolaba** un `Task`, el `guard let pending` del cuerpo
se encontraba el estado ya limpio.

Y el segundo desenlace es peor que el no-op: si la escritura cae **durante el `await`**, el Task ya
capturó sus datos pero `selectedCurrency` vuelve a la divisa vieja, y el `save()` posterior escribe
la divisa **vieja** sobre el histórico ya convertido — **el bug del ticket, creado por su arreglo**.
Es otra instancia de [[mi-fix-hereda-la-forma-del-bug]].

**How to apply:**

- **El `set` de un binding de alert solo cierra.** Revertir, limpiar o navegar es trabajo de los
  botones, que lo hacen explícitamente y se sabe cuál corrió.
- **Un dato que necesita una acción `async` viaja por PARÁMETRO, no se lee del estado dentro del
  `Task`.** Léelo síncronamente en el `actions` builder (`let pending = viewModel.pending…`) y
  pásalo. Entonces el orden deja de importar.
- **Y reafirma en el destino lo que el `await` pudo perder.** Si el estado que decide qué se
  persiste puede cambiar durante la espera, fíjalo desde el parámetro antes de guardar.
- **El patrón que parece igual y sí funciona:** los tres precedentes del repo
  (`currencyToSuggestAsSecondary`, `GroupRecordsView`, `GroupsContainerView`) leen el opcional
  **síncronamente dentro de la acción**. Lo que rompe la equivalencia es meter el trabajo en un
  `Task`, no la forma del binding.
- **Ningún test del ViewModel lo habría visto** —llaman al método directo, sin binding— y el
  `accessibilityIdentifier` del botón es un no-op dentro de un `.alert`
  (`docs/aprendizajes-tecnicos.md`, 2026-09-04), así que tampoco hay XCUITest posible. Lo que sí
  fija el arreglo es un test que **limpia el estado antes de llamar**, reproduciendo el peor orden.

Hermana de la regla de `.claude/rules/swiftui-ds.md` sobre `.alert`: allí lo prohibido es un
**label** de botón dependiente de `@State` (el título dinámico sí pasa). Esto es otra cosa —el
binding— y las dos muerden en silencio.
