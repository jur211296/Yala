---
id: groups-history-cutoff-needs-synced-state
status: backlog
priority: very-low
area: "groups, bridge"
created: 2026-09-11
source: "paso 8 del rediseño de sesiones (`full-mode-activation-must-ask-where-personal-data-lives`), decisión D8 del Paso 0"
updated: 2026-10-08
---

# «No traer mis gastos de grupo» también oculta los que vengan después

## El síntoma, en lenguaje de usuario

Activo Yala completo desde solo-grupos y la app me pregunta: «¿Traemos tus gastos de grupo?». Si digo
«No, dejarlos en Grupos», dejan de verse en el total del Panel, en Registros y en Estadísticas… los de
antes **y** los que registre a partir de ahora. La decisión de Jürgen (2026-09-09) hablaba de «los
gastos de grupo que ya existían».

## Por qué quedó así (medido el 2026-09-11)

- **Las filas ya existen.** El bridge de solo-grupos crea cada gasto en la cuenta de sistema «Grupos» del
  store personal (`GroupTransactionBridge.createGroupInviteCaseAVirtualPair`), y sin tocar nada salen en
  Panel, Registros, Estadísticas y Presupuestos en cuanto la app es completa. El «Sí» del paso 8 las deja
  como están (cero escrituras); el «No» apaga los tres toggles que ya existen en Ajustes de Grupos
  (`includeGroupTransactionsInFeed`, `includeGroupsInPanelTotal`, `includeGroupTransactionsInStats`):
  datos intactos, reversible y sincronizado.
- **«Solo el pasado» necesita saber, en CADA re-puenteo, si un gasto es anterior a la activación.**
  `SplitExpense.createdAt` no sirve entre dispositivos: la emisión del backend omite `created_at`, así
  que un dispositivo que baja el gasto después lo fecha al bajarlo.
- **Sin un corte sincronizado, cualquier versión «solo el pasado» es un error de dinero.** La natural
  —borrar las filas anteriores y colapsarlas en un saldo de apertura de «Grupos», para que el número que
  se ve no cambie— se rompe en el segundo dispositivo: su bridge re-puentea el historial y el saldo de
  «Grupos» se duplica. Y editar un gasto anterior también lo re-puentearía encima del saldo de apertura.

## Opciones

1. **Corte sincronizado** (lista de ids o marca de servidor que viaje con el corpus personal) + gate en
   `bridgeExpense` / `bridgeSettlement` + saldo de apertura por cuenta de sistema. Toca el bridge: review
   adversarial obligatoria.
2. **Dejarlo como está**, si Jürgen prefiere que «No» signifique «mantener Grupos aparte de mis finanzas».
   Entonces lo que cambia es el copy de la pregunta, no el código.

## Criterios de aceptación

- [ ] Jürgen elige (1) o (2).
- [ ] Si (1): el saldo de «Grupos» no cambia al elegir «No»; un segundo dispositivo no trae de vuelta el
      historial; editar un gasto anterior no lo trae de vuelta; los nuevos sí se ven.

## Medido en 2.1 (triage 2026-10-08)
- El pie de la pregunta ya dice «Vale también para los que registres después. Puedes cambiarlo cuando quieras en Ajustes de Grupos.» (`groups.fullActivation.historyFootnote`, `es-419` `Localizable.strings:5787`, pintado en `FullModeActivationFinaleView.swift:138`, desde `697b5c9a1`). La opción 2 ya está aplicada en el copy.
- `GroupTransactionBridge` no tiene corte por fecha: la opción 1 sigue sin empezar.

## Pregunta para Jürgen (triage 2026-10-08)
- **A.** Corte sincronizado («solo lo de antes»): toca el bridge y el saldo de «Grupos», con review adversarial obligatoria.
- **B.** Dejarlo: «No» = mantener Grupos aparte de mis finanzas, como ya dice el pie de la pregunta.
- **Recomendación: B** — el copy ya es honesto y el cambio es reversible en Ajustes; A es un cambio de dinero caro. Con B no queda trabajo (se descartaría), por eso `very-low`.

Triage 2026-10-08: abierto · medium → very-low · Comportamiento sin cambios, pero el copy ya lo dice desde 697b5c9a1 («Vale también para los que registres después»); solo falta que Jürgen elija entre corte sincronizado o dejarlo.
