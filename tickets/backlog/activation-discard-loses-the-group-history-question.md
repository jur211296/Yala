---
id: activation-discard-loses-the-group-history-question
status: backlog
priority: low
area: "onboarding, grupos"
created: 2026-09-14
updated: 2026-10-08
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

## El mismo hueco tras «Vaciar datos» en solo-grupos (2026-09-27)

Lo encontró la review de `wipe-data-keeps-groups-but-drops-their-bridged-rows`. «Vaciar datos» en una sesión solo-grupos
se lleva las filas del bridge y deja pedida la convergencia, que espera a la activación. Al activar Yala completo,
`bridgedGroupExpenseCount()` da 0, la pregunta no sale y la convergencia del arranque siguiente trae el historial con la
visibilidad por defecto. Se eligió así a propósito: sin la convergencia esas filas no volverían nunca. El arreglo que se
elija aquí tiene que cubrir también este camino.

## Pregunta para Jürgen (triage 2026-10-08)

- **A.** Preguntar siempre que haya gastos de grupo, contándolos en el dominio de grupos y no en las filas ya puenteadas. Cubre a la vez «Empezar desde cero» y «Vaciar datos» en solo-grupos.
- **B.** Medir el conteo antes del borrado. Cubre «Empezar desde cero», pero no «Vaciar datos», donde las filas ya se fueron antes.
- **C.** No preguntar a quien empieza de cero, y dejar escrito que el valor por defecto es la respuesta.

**Recomendación: A.** Iguala las dos puertas con un solo cambio. Con A la prioridad es `low`: solo decide la visibilidad, y se cambia luego en Ajustes.

## Medido en 2.1 (triage 2026-10-08)

- `shouldAskHistory` abre con `guard bridgedGroupExpenseCount > 0` (`Yala/App/Logic/FullModeActivationFlowLogic.swift:316-317`).
- `bridgedGroupExpenseCount()` (`Yala/App/Views/Groups/FullModeActivationView.swift:498-509`) sigue contando `TransactionItem` puenteadas en `onboardingFinished` (`:383-395`), después del borrado. Los dos caminos (descartar y «Vaciar datos» solo-grupos) siguen sin pregunta.

Triage 2026-10-08: abierto · medium → low · el conteo sigue tras el borrado (FullModeActivationView.swift:498) y la pregunta no sale; falta decidir si se pregunta (pregunta A/B/C).
