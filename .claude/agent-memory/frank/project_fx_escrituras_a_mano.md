---
name: fx-escrituras-a-mano
description: PR #94 — las escrituras a mano del monto convertido ya no sellan una tasa aproximada; eran 14 y no 10, falta device-QA que NO es simulable, y quedan dos hallazgos con ticket propio.
metadata:
  type: project
---

**`fx-manual-writes-seal-approximate-as-final` está cerrado en código: PR #94, ticket en
`tickets/qa/`.** Catorce escrituras a mano de `amountInPreferredCurrency` pasan a `convertChecked` y
fijan `isExchangeRateProvisional = !quality.isExact`, que es lo que les devuelve la ruta de auto-cura
del reparador.

**Why:** `CurrencyConverter.convert` devuelve `Decimal` a secas y tira la calidad de la tasa. El
reparador (`TransactionUpdateService`) tiene un `#Predicate` que solo busca `== true`, así que una
transacción sellada en `false` con una tasa aproximada no se revisitaba nunca: el número malo se
quedaba para siempre, viajaba por la nube y alimentaba los informes.

**How to apply:**

- **El conteo del ticket estaba corto: decía diez y son catorce.** Su grep buscaba la asignación
  (`.amountInPreferredCurrency =`) y no veía las cuatro que pasan el monto por **init**. Si alguien
  cita «los diez sitios», es la lista vieja. Las que faltaban: las **tres ramas de creación** de
  `NewTransactionViewModel` (el ticket listaba solo las de edición del mismo fichero, así que «el
  flujo principal» estaba cubierto a medias) y `ChatAssistantViewModel`.
- **El AC nº 2 pedía algo que no procede y no se hizo.** Decía que `CurrencyChangeService` «no bajara
  el flag de una transacción que ya lo tenía en alto», pero ese bucle **no tocaba el flag en
  absoluto**; el daño era el contrario. La decisión quedó **incondicional**, igual que en
  `recalculatePreferredCurrency`: el flag describe la calidad del número que hay AHORA, no un
  historial. Un `flag = flag || !isExact` dejaría transacciones ya exactas marcadas para siempre. Hay
  un test para esa tercera dirección — **no lo "arregles" hacia el AC literal.**
- **Device-QA pendiente y NO es simulable**, por el mismo motivo que el resto del área
  `fx-conversion-persistence`: hace falta red y un histórico real de tasas con una fila a la que le
  falte una divisa. La red que hay es unit + mutación (quitar la decisión pone 4 casos en rojo).
- **Creación y transferencia** están cubiertas por barrido de fuente, no por comportamiento:
  `save(context:)` arrastra `WidgetDataCache`, `RouterEntryGate`, `SessionState` y un `Task` sin
  await. Si alguien quiere el test de comportamiento, ése es el coste.
- **`InitialBalanceService` y los seeds NO son bug** aunque el barrido los liste como «sin flag»: el
  primero llama `recalculatePreferredCurrency` justo después, y los segundos son datos sintéticos.

**Dos hallazgos de camino salieron con ticket propio, y el primero importa:**

- `currency-change-service-tests-mirror-the-logic` (medium) — los siete casos de
  `CurrencyChangeServiceTests` **reimplementan la lógica dentro del test** («Mirrors the rate
  derivation logic») en vez de llamar al servicio. Siguieron verdes con este bug dentro. El peor de
  los catorce sitios no tenía ninguna red. Ya está demostrado que **sí es testeable de
  comportamiento y barato**: `ensureRates` no toca red si la fila del rango ya existe.
- `chat-assistant-plants-exchange-rate-one` — **CERRADO el 2026-09-08**. Subió a `medium` y se
  arregló: la ruta del chat deriva la tasa como las otras seis. Lo que aquí se dio por bueno era
  falso — «se cura sola cuando la conversión fue aproximada» describe la MINORÍA de las ejecuciones;
  en el caso exacto el flag queda `false`, la fila sale del `#Predicate` del reparador y el 1.0 se
  sellaba para siempre. El barrido de las 18 construcciones de `TransactionItem` confirmó que era el
  ÚNICO sitio del árbol que plantaba tasa falsa habiendo conversión real.

Relacionado: [[fx-pnl-card]] · [[mi-fix-hereda-la-forma-del-bug]] (el barrido de este ticket nació
con el bug que persigue) · [[mutante-compilado-zanja-hipotesis]] (así se verificó).
