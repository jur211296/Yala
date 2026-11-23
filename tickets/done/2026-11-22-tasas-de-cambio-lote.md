---
id: 2026-11-22-tasas-de-cambio-lote
status: done
area: "divisas, tasas"
created: 2026-11-22
updated: 2026-11-22
source: "Jürgen pidió el 22-nov (15:08 Lima) encolar lo pendiente del backlog que esté claro o tenga decisión. Encargo `encargos/lanzados/2026-11-22-tasas-de-cambio-lote.md`, con su Paso 0."
---

# Tasas de cambio: una sola tasa por día, claves gregorianas, tasas de hoy al volver y saldo inicial al mover la fecha

Junta cuatro tickets afines, cerrados con su evidencia:

- `tickets/done/duplicate-exchange-rate-rows-pick-an-arbitrary-rate.md`
- `tickets/done/exchange-rate-date-keys-follow-the-phone-calendar.md`
- `tickets/done/volver-de-segundo-plano-en-un-dia-nuevo-no-trae-las-tasas.md`
- `tickets/done/initial-balance-date-move-leaves-converted-amount-stale.md`

## Qué cambia para el usuario

- Un movimiento en otra divisa sale con el mismo importe convertido en todos sus iPhone y en cada arranque, aunque el
  tipo de cambio de ese día haya llegado de varios dispositivos.
- Con el iPhone en calendario budista o japonés, las tasas se guardan y se buscan con la fecha de todos, y la
  conversión deja de caer en la tabla aproximada.
- Volver a Yala al día siguiente sin cerrarla pide el tipo de cambio de hoy: el «≈» ya no se queda todo el día.
- Importar movimientos más antiguos que el saldo inicial de una cuenta en otra divisa recalcula su importe convertido
  con la tasa de la fecha nueva.

## Paso 0 (decidido al empezar, 2026-11-22, modo nocturno)

Medido contra `origin/2.3` (`c6affe870`): los cuatro tickets siguen abiertos en el código.

1. **Copias del mismo día — regla de lectura.** La de `ExchangeRateDuplicateLogic` (la de «Activar la nube»): de la
   copia más vieja a la más nueva por hora, luego `syncID`, y en cada divisa gana la más nueva. Se extiende con dos
   desempates para filas sin hora ni identidad (cuántas divisas trae, luego el contenido), porque en `.icloud` casi
   ninguna tasa tiene `syncID`. Una tasa inservible no pisa a una buena de otra copia. Vale para las tres rutas del
   converter, la caché del TC actual y las preguntas de cobertura de `ExchangeRateService`.
2. **Copias del mismo día — limpieza.** Una vez por día y proceso, al pedir las tasas de hoy: se funden solo los
   días cuyas copias traen TODAS `syncID` (superviviente el menor, la regla de los dos dispositivos). Sin identidad no
   se borra nada: dos teléfonos podrían borrar cada uno la del otro. Solo en `.icloud` o con el motor de la nube en marcha.
3. **Calendario.** `en_US_POSIX` + gregoriano en los tres formatters de claves (converter, servicio y API). Las filas
   ya guardadas con otra era **se descartan**, no se re-claven: el año japonés no dice de qué era es, y la tasa se
   vuelve a pedir si hace falta. Las tres pantallas que solo PARSEAN una clave para enseñar «última actualización»
   quedan fuera del toca: anotado.
4. **Vuelta a primer plano.** `AppBootstrapper.handleBecameActive` (fuera del toca, mínimo) llama a
   `updateTodayIfNeeded` en las vueltas, no en el arranque. `needsExchangeRateReload` ya tiene escritor
   (`UsageModeService`): el segundo criterio del ticket ya se cumple y no se toca.
5. **Saldo inicial.** `updateInitialBalanceDateIfNeeded` recalcula tras mover la fecha, sin `save()` (el contrato con
   sus cuatro llamadores no cambia). Sin la tasa del día nuevo, queda provisional y la cura el reparador.
6. **Fuera del toca, mínimo:** `ExchangeRateDuplicateLogic.swift` (la regla vive ahí) y `AppBootstrapper.swift`.
7. Sin textos nuevos: nada de l10n.
