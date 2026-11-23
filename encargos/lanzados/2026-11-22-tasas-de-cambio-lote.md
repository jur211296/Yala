Yala
# Tasas de cambio: una sola tasa por día, fechas en calendario gregoriano, tasas de hoy al volver y saldo inicial al mover la fecha
---
toca: Yala/Services/CurrencyConverter.swift,Yala/Services/ExchangeRateService.swift,Yala/Services/ExchangeRateProvider.swift,Yala/Services/ExchangeRateAPIService.swift,Yala/Services/InitialBalanceService.swift,YalaTests/TasasDeCambioLote/,tickets/backlog/duplicate-exchange-rate-rows-pick-an-arbitrary-rate.md,tickets/backlog/exchange-rate-date-keys-follow-the-phone-calendar.md,tickets/backlog/volver-de-segundo-plano-en-un-dia-nuevo-no-trae-las-tasas.md,tickets/backlog/initial-balance-date-move-leaves-converted-amount-stale.md,tickets/done/duplicate-exchange-rate-rows-pick-an-arbitrary-rate.md,tickets/done/exchange-rate-date-keys-follow-the-phone-calendar.md,tickets/done/volver-de-segundo-plano-en-un-dia-nuevo-no-trae-las-tasas.md,tickets/done/initial-balance-date-move-leaves-converted-amount-stale.md,tickets/backlog/2026-11-22-tasas-de-cambio-lote.md,tickets/done/2026-11-22-tasas-de-cambio-lote.md
esfuerzo: medium
cierre: cierra-sola
---

Jürgen pidió el 22-nov (15:08 Lima) encolar todo lo pendiente del backlog que esté claro o tenga decisión. Este encargo junta tickets afines.

## Tickets
- `tickets/backlog/duplicate-exchange-rate-rows-pick-an-arbitrary-rate.md`
- `tickets/backlog/exchange-rate-date-keys-follow-the-phone-calendar.md`
- `tickets/backlog/volver-de-segundo-plano-en-un-dia-nuevo-no-trae-las-tasas.md`
- `tickets/backlog/initial-balance-date-move-leaves-converted-amount-stale.md`

## Qué hacer
Con dos filas de tasas del mismo día se usa una regla fija y se limpian los duplicados. Las llaves de fecha usan calendario gregoriano aunque el teléfono tenga otro. Volver a la app en un día nuevo pide las tasas de hoy (si el disparador vive fuera del toca, toca lo mínimo). Mover la fecha del saldo inicial recalcula el monto convertido con la tasa del día nuevo.

## Reglas
- Antes de tocar nada, verifica contra `origin/2.3` que cada ticket siga pasando (varios son viejos). Si uno ya no pasa o ya está hecho, muévelo a done con la evidencia y sigue con los demás.
- Si un ticket resulta ser una decisión de diseño o de producto que solo Jürgen puede tomar, no la inventes: déjalo en backlog con la pregunta y las opciones con su recomendación, y anótalo en el cierre.
- Textos nuevos en su propia tabla `.strings` (la del toca), no en Localizable.strings ni L10n.swift, en los 16 idiomas y siempre en español neutro latinoamericano (en es-ES también, sin vosotros).
- Si hace falta tocar algo fuera del toca, toca lo mínimo y anótalo en el cierre.
- Producción (iCloud Production, Supabase prod, gateway, web publicada) no se toca: déjalo probado en desarrollo y anotado para Dan, con el OK de Jürgen.
- Nada de pago.

## Dispositivos
Antes de usar un simulador, comprueba si el iPhone 14 conectado por DeviceMCP está libre; no lo des por ocupado sin comprobarlo. En la Max puedes usar un segundo simulador si otra sesión ya usa uno (tope 2); en la Mini, 1.

## Cierre
Commits y PR sin firma de IA y sin saltarse hooks. Espera el merge real del PR en 2.3 antes de `/cerrar-total`. Si a los ~45 min el CI sigue rojo por algo ajeno al PR, cierra y anótalo. El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada».

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
