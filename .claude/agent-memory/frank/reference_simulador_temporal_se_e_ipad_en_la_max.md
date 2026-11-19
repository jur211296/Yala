---
name: simulador-temporal-se-e-ipad-en-la-max
description: Para probar en iPhone chico e iPad en la Max se crean simuladores temporales; hay dos runtimes 27.2 y el del Duo rechaza SE/iPad
metadata:
  type: reference
---

En la Max solo hay un `iPhone 17 Pro` de Yala (más los `Mando-*`, que son de otro proyecto: no se usan). Para el
iPhone chico y el iPad, crear y borrar al acabar (medido el 2026-11-19):

- `xcrun simctl list runtimes` trae DOS iOS 27.2: `…iOS-27-2-iPhone19-4` (el del Duo) y `…iOS-27-2`. Con el del Duo,
  `simctl create` de un SE o un iPad da «Incompatible device» (403). Usa `com.apple.CoreSimulator.SimRuntime.iOS-27-2`.
- Tipos que valen: `iPhone-SE-3rd-generation`, `iPad-Pro-13-inch-M5-12GB`. Arrancar de uno en uno con el 17 Pro
  (tope 2, [[segundo-simulador-en-la-max]]), correr `test-without-building` por `id=` y `delete` al terminar.
- En el iPad el «+» flotante del Panel no existe: Nuevo registro se abre con `panel_action_new`, que vale en los dos.

Y el artifact: en la organización de claude.ai de la Max, «Cualquier persona con el enlace» sale desactivado en
Compartir (2026-11-19). Se intenta igual (ADR-123) y se anota «privado» en el cierre.
