---
name: tours-de-ajustes-y-pro-no-se-capturan
description: Los coach tips de Ajustes y el tour Pro no salen con -uitest, y sin -uitest la app pide la bienvenida: para una maqueta se recrean sobre capturas reales.
metadata:
  type: reference
---

Medido el 2026-11-20 (maquetas de Primeros pasos, simulador de la Max): `ProfileView` calla el tour de Ajustes y el
tour Pro con `guard !UITestHooks.isActive`, y relanzar Yala Dev sin `-uitest` tras una corrida con semilla abre la
bienvenida (Google / Apple / iCloud privado), no el Panel. No hay atajo `-uitest-*` que los muestre.

**How to apply:** si una maqueta necesita el «hoy» de esos tours, captura Ajustes con `-uitest` y dibuja encima la
tarjeta de `CoachMarkOverlay` (píldora «1 de 3», título, mensaje, «Omitir guía» / «Siguiente»), avisando en la
entrega que está recreado. Pasar por la bienvenida real cuesta una cuenta de iCloud en el simulador.
Relacionado: [[axe-primer-toque-y-mazo-en-un-paso]].
