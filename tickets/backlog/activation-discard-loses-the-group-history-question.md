---
id: activation-discard-loses-the-group-history-question
status: backlog
priority: medium
area: "onboarding, grupos"
created: 2026-09-14
source: "review adversarial del PR de `activation-restore-start-fresh-keeps-the-imported-rows` (tres lentes coincidieron, 2026-09-14)"
---

# Tras «Empezar desde cero» nadie pregunta si traer los gastos de grupo a lo personal

## El síntoma, en lenguaje de usuario

Activo Yala completo, descarto mis datos viejos y termino el onboarding. La app **no me pregunta** si
quiero ver los gastos de mis grupos en mi Panel y mis Registros — una pregunta que sí le sale a quien
activa por el otro camino. La decisión se toma por mí, con el valor por defecto.

## Lo medido (2026-09-14, en el PR que cierra el ticket padre)

- `shouldAskHistory` (`FullModeActivationFlowLogic.swift:289-290`) abre con
  `guard bridgedGroupExpenseCount > 0`, y `bridgedGroupExpenseCount()`
  (`FullModeActivationView.swift:464-475`) cuenta `TransactionItem` con `splitExpenseID != nil`.
- Ese conteo se hace en `onboardingFinished`, o sea **después** del borrado, que se llevó esas filas
  (`wipeAllUserData` borra `TransactionItem` sin predicado). ⇒ devuelve **0** ⇒ la pantalla no sale y
  `applyHistoryChoice()` sale por su primer `guard` sin escribir nada.
- **Las filas sí vuelven**: el PR padre deja pedida la convergencia del bridge
  (`GroupsBridgeRestoreConvergenceStore.markPending()`), que `AppBootstrapper` ejecuta en el arranque
  siguiente y re-puentea el dominio entero. Lo que no vuelve es la PREGUNTA, así que los toggles de
  visibilidad se quedan en su default.
- El camino `.privateGate` (sin borrado) sí pregunta. Las dos puertas divergen.

## Qué hay que decidir

**¿Se le pregunta a quien acaba de descartar su corpus personal?** Hay argumento para las dos:

- **Sí**: es la misma decisión de producto que para cualquier otra activación, y el default («mostrarlos»)
  no es obviamente lo que quiere quien acaba de limpiar.
- **No**: quien descarta está declarando «empiezo de cero», y una pregunta más sobre datos que todavía no
  han vuelto (la convergencia es del arranque siguiente) es ruido.

Si se elige «sí», lo barato es **medir el conteo ANTES del borrado** y llevarlo con la decisión.

## Criterios de aceptación

- [ ] La decisión queda escrita en el ticket antes de tocar código.
- [ ] Si se pregunta: la pantalla sale con el conteo real de antes del borrado, y la respuesta se aplica
      cuando la convergencia repone las filas.

## Relacionados

- [[activation-restore-start-fresh-keeps-the-imported-rows]] — el padre.
