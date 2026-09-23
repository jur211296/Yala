---
id: reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last
status: done
priority: medium
area: "modo-nube, migración"
created: 2026-09-22
updated: 2026-09-23
source: "review adversarial de `reverse-verify-network-bucket-hides-a-definitive-server-no` (2026-09-22), dos lentes independientes lo cazaron por separado"
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - el ticket dice que su escenario no se monta a mano; MigrationRunnerTests
---

# Un fallo de UNA vez cobra las horas que otro motivo llevaba esperando, y saca de la vuelta sin un solo reintento

## El problema, en lenguaje de usuario

Llevo tres horas volviendo a iCloud sin cobertura. La app espera, que es lo correcto: la red vuelve sola. Vuelve el
wifi, y justo en esa pasada algo del teléfono falla una vez —una lectura de la base local que no sale—. En vez de
reintentar, la app abandona la vuelta **en ese mismo instante** y me manda de vuelta al principio.

Si ese mismo fallo me hubiera pasado a los dos minutos de empezar, no habría pasado nada: habría esperado y
reintentado. Lo que me saca no es el fallo, es haber esperado mucho antes por otra cosa.

## Por qué pasa (medido el 2026-09-22)

`MigrationRunner.observeReversePreMountStall` mide **dos cosas de procedencias distintas** y las junta:

- `stalled = observedAt - lastProgressAt` es el tiempo parado **de la FASE**, y el sello solo se reinicia al CAMBIAR
  de fase (`MigrationRunner.swift`, la rama `sealedPhase != phase`). Una espera de 3 h por red no lo mueve.
- `cause = blocker?.stallCause ?? .unknown` es de **ESTA observación**, la última.

`MigrationStateMachine` aplica el presupuesto de la causa actual al tiempo acumulado (`guard stalled >= budget`). Con
3 h acumuladas y una causa que elige el techo corto, `10 800 >= 900` sale a la primera. No hay histéresis, ni segunda
observación, ni reintento.

**Existe desde el 2026-09-21** (`reverse-before-mount-has-no-way-to-abandon-the-return`), cuando el 403 estrenó el
techo corto, y ahí molestaba menos: un 403 es una respuesta del servidor, repetible, y el argumento «esperar no lo
arregla» se sostiene. **Lo que lo vuelve urgente es el 2026-09-22**
(`reverse-verify-network-bucket-hides-a-definitive-server-no`): desde ese día el techo corto también lo elige
`.localFailure`, que lo decide **una** excepción de un `fetch` de SwiftData — y eso sí puede ser pasajero.

## Qué habría que decidir antes de hacerlo

1. **¿Histéresis o reloj por causa?** Exigir DOS observaciones seguidas con causa definitiva antes de acortar es lo
   barato; llevar un reloj por causa es lo correcto y toca el journal (schema nuevo).
2. **¿Aplica a los cinco motivos o solo a los que no son del servidor?** El 403 repetido no necesita histéresis; el
   `fetch` local sí. Distinguirlos deja el mecanismo con dos reglas.
3. **El schema.** `reversePreMountProgressAt` es un solo campo; un reloj por causa son cinco, o uno más la causa
   sellada.

## Paso 0 — el árbol de decisiones, resuelto

**Tres las trajo Jürgen resueltas en el encargo** (2026-09-22) y no se reabren:

1. **Reloj por causa**, no histéresis. El techo corto solo cuenta el tiempo acumulado bajo ESA causa. Toca schema.
2. **Un solo mecanismo para los cinco motivos.** Nada de «regla del servidor» vs «regla local»: el mismo reloj por
   causa para los cinco. Norma: la opción más robusta, nunca la más simple.
3. El residual hermano `verify-reads-a-failed-local-fetch-as-an-empty-outbox` **no entra aquí**.

Las cuatro que quedaban se contestan solas, con la misma norma:

4. **¿El techo LARGO sigue aplicando cuando la causa es definitiva?** **Sí, y es lo que hace robusto el
   mecanismo.** La condición de salida pasa a ser `reloj de FASE ≥ 72 h` **O** `reloj de CAUSA ≥ 15 min`. Sin la
   primera mitad, dos causas definitivas que se alternen —un 403 y un `fetch` local que fallan a turnos— dejarían
   la vuelta parada **para siempre**: el reloj de causa se re-sella en cada cambio y el corto nunca vence. Eso es
   exactamente el bug-class que esta familia existe para cerrar (una espera sin techo), reintroducido por la
   puerta de al lado. El techo largo se queda como red de último recurso para CUALQUIER causa, y no se relaja.

5. **¿El reloj de causa es una racha CONSECUTIVA o un acumulado por motivo?** **ACUMULADO, con pausa.** El Paso 0
   eligió primero la racha consecutiva —más barata, un sello— y **la review la tumbó con una medición**: la
   pantalla de Almacenamiento re-kickea cada 30 s, así que con una cuenta suspendida y cobertura intermitente
   basta un timeout de red cada quince minutos para que la racha no llegue NUNCA a los 900 s. El techo corto se
   volvía inalcanzable justo cuando más se mira la pantalla, y el desenlace pasaba de 15 min a **72 h**. Releída,
   la decisión 1 de Jürgen ya lo decía: «tiempo **acumulado** bajo ESA causa».
   Una observación SIN motivo **pausa** el reloj: cierra el tramo y conserva lo acumulado. Un hueco no prueba que
   el motivo se fuera, solo que no se pudo preguntar. Un cambio de CAUSA sí tira lo acumulado del anterior, y la
   clave es el `rawValue` del blocker, no su `abortReason`: `accountUnavailable` y `refused` comparten copy, y
   fundirlos sumaría dos causas como si fueran una.

6. **El schema.** TRES campos ADITIVOS y opcionales, v7 → v8: `reversePreMountCauseRaw` (qué causa),
   `reversePreMountCauseAt` (desde cuándo corre el tramo abierto; `nil` = pausado) y
   `reversePreMountCauseAccruedSeconds` (lo cerrado). Una fila v7 se abre con los tres a `nil` y la primera
   observación con motivo los estrena: el techo corto le cuenta desde que este build la mira.

7. **El canario.** `cloudReversePreMountWaiting` publica **los DOS tramos**:
   `<fase>|<tramo de fase>|<tramo de causa>|<causa>`, con `-` en el de causa cuando no hay motivo. El Paso 0
   eligió publicar solo «el reloj que decide» y **la review midió las dos direcciones del error**: con solo el de
   fase, `stop_localFailure|1h_24h` se lee como tres horas de avería local cuando lleva doce segundos; con solo el
   de causa, un teléfono con dos motivos alternándose 72 h publica `lt_15m` en cada observación y —con el dedupe
   por proceso— la flota ve UN evento diciendo que no pasa nada. Caben: el peor caso mide 46 de los 128
   caracteres que admite el gateway, y hay test que lo fija. La serie **vuelve a cambiar de valores con este
   build**, un día después del cambio anterior.

8. **El motivo que se journalea al salir lo elige el techo que VENCIÓ**, no la última observación. Lo cazaron dos
   lentes: con dos relojes, la vuelta puede salir por el techo de FASE —72 h sin cobertura— en una pasada que
   casualmente traiga un 403 recién visto, y journalear `preMountRefused` ahí le da el correo de soporte a quien
   llevaba tres días sin red. El predicado del techo corto vive en UN solo sitio
   (`MigrationPolicy.reversePreMountCauseCeilingReached`) porque lo consultan la máquina y el runner, y tenerlo
   escrito dos veces es la forma de que un día discrepen.

9. **Los dos presupuestos se renombran.** `reversePreMountDefinitiveBudgetSeconds` →
   `reversePreMountCauseBudgetSeconds` y `reversePreMountUnknownBudgetSeconds` → `reversePreMountPhaseBudgetSeconds`.
   El segundo dejó de ser «el de lo desconocido» al aplicar con cualquier causa, y quien grepeara `Unknown` habría
   bajado el techo de las definitivas sin querer.

## Qué se toca

| Fichero | Qué cambia |
|---|---|
| `MigrationState.swift` | Los tres campos aditivos, v8, y `clearReversePreMountCeiling()` — cinco campos que se limpian juntos en SEIS sitios; sin el helper, el sexto que entre se olvidará en alguno |
| `MigrationRunner.swift` | `reversePreMountCauseClock` (acumula, pausa, re-ancla) y `reversePreMountExitReason` (el motivo lo elige el techo que venció) |
| `MigrationStateMachine.swift` | El evento gana `causeStalledSeconds`; la salida pasa a ser `largo(fase) OR corto(causa)`; los dos presupuestos se renombran y el predicado del corto se extrae a la policy |
| `CloudSyncEngine.swift` | El breadcrumb dice los DOS relojes: sin eso, el rastro de un techo no deja ver cuál venció |
| `MetricsService.swift` | El canario publica los dos tramos |

## Qué cazó la review adversarial

Cuatro lentes independientes, **seis defectos míos**, tres de ellos vistos por dos lentes por separado:

1. La racha consecutiva volvía el techo corto inalcanzable con red intermitente (→ decisión 5, acumulado).
2. El motivo journaleado lo escribía un blocker de 0 s en una salida por techo de fase (→ decisión 8).
3. El canario dejaba ciego uno de los dos relojes (→ decisión 7).
4. Los nombres de los presupuestos mentían (→ decisión 9).
5. El test del helper prometía cazar un campo nuevo de la familia y **no podía**: una lista literal comparada
   consigo misma deja verde un sexto campo. Ahora la familia se deriva del schema.
6. Faltaban cinco casos: el clear en dos call sites, el sello del tramo en el futuro, dos causas que comparten
   `abortReason`, el cambio de fase con causa acumulada, y el round-trip `save + refetch` de los cinco campos —
   este último con un modo de fallo silencioso que deshace los dos tickets a la vez.

**Un hallazgo refutado, y por medición**: dos lentes pidieron un cinturón `sealedPhase == phase` en la lectura del
reloj de causa. La lente de corrección enumeró los tres `setPhase` que no pasan por `handle` y comprobó que los
tres limpian o no cambian de fase, así que la condición sería inalcanzable — y una condición inalcanzable recoge
lo que el camino bueno deja pasar sin que ningún test pueda matarla. En su lugar entró el test del call site.

## Criterios de aceptación

- [x] Un `.localFailure` aislado tras una espera larga por otra causa **reintenta al menos una vez** antes de sacar
      a la persona de la vuelta.
      → `reversePreMountCauseClock_anIsolatedLocalFailureAfterALongWait_retriesInsteadOfLeaving`
- [x] Un 403 repetido sigue saliendo a los 900 s de parada REAL con esa causa.
      → `reversePreMountCauseClock_aRepeatedRefusalStillLeavesAt900SecondsOfItsOwn` (899 holdea, 900 sale)
- [x] La red pura conserva su techo largo, y el cambio de fase sigue reiniciando el reloj.
      → `reversePreMountCeiling_networkAndExpiredSession_useTheLongBudget` y
      `reversePreMountCauseClock_changingPhase_resetsTheAccumulatedCause`
- [x] Test que siembre una espera larga con una causa y observe con otra: hoy sale al instante y debe holdear.
      → el primero de la lista, con el reloj de fase sembrado en 3 h

## Guion de QA (device, iPhone)

Hace falta una cuenta en la nube con la migración terminada y el teléfono en modo nube. **El 403 no se puede montar
desde el teléfono**: se provoca en staging.

**Y hay que decir lo que este guion NO cubre.** El escenario exacto del ticket —tres horas de espera por red y un
fallo de la base local justo en la pasada en que vuelve el wifi— **no se monta a mano**: pide esperar tres horas y
provocar un `fetch` de SwiftData que lance en el instante justo. Esa mitad la cubren los tests
(`reversePreMountCauseClock_anIsolatedLocalFailureAfterALongWait_retriesInsteadOfLeaving`). Lo que sí se comprueba
en el teléfono es que **el resto del mecanismo no se rompió**, que es donde un error saldría caro.

1. En Ajustes → «¿Dónde viven tus datos?», toca **«Volver a iCloud»** y acepta. La barra debe pasar del claim al
   drenaje.

2. **El 403 repetido sigue saliendo a los 15 minutos.** Con la vuelta en «Comprobando que todo llegó…», suspende la
   cuenta en staging (el gateway debe responder 403 a `/sync/merkle`). Deja Yala abierta en la pantalla de
   Almacenamiento y mira el reloj.
   - **Espera:** a los **15 minutos** la tarjeta desaparece y queda la nota «tu cuenta en la nube no lo permitió»,
     con el correo de soporte. Ni antes ni tres días después.
   - **Esto es lo que más importa medir**, porque es la mitad que el cambio podría haber roto: si el reloj de causa
     no persiste, este paso **no termina nunca** y solo saldría a las 72 h.

3. **La pausa: un corte de red NO reinicia la cuenta.** Repite el paso 2, pero a los **7 minutos** pon el teléfono
   en modo avión un minuto y quítalo.
   - **Espera:** la salida llega a los **~15 minutos de 403**, no a los 22. El minuto sin cobertura ni suma ni
     resta. Antes de este arreglo (y con una racha consecutiva) el contador se habría puesto a cero y **no habría
     salido nunca** mientras la cobertura fuera intermitente.

4. **Control: la red pura conserva su plazo largo.** Restaura la cuenta, relanza la vuelta y pon el teléfono en modo
   avión durante la comprobación.
   - **Espera:** a los 15 minutos la vuelta **sigue ahí**. No se ha ido a ninguna parte.

5. **Control: un intento nuevo empieza de cero.** Tras la salida del paso 2, restaura la cuenta y vuelve a tocar
   «Volver a iCloud».
   - **Espera:** la vuelta nueva **arranca y espera**. Si saliera en el acto, el reloj del intento anterior se
     habría quedado puesto.

6. **El copy, en los dos casos.** Comprueba que la nota del paso 2 menciona la cuenta y da soporte, y que **ninguna**
   de las salidas de los pasos 3-5 lo hace.

## Relacionado

- `reverse-verify-network-bucket-hides-a-definitive-server-no` — el que metió `.localFailure` en el techo corto.
- `reverse-before-mount-has-no-way-to-abandon-the-return` — el que creó el techo y su reloj por fase.
- `verify-reads-a-failed-local-fetch-as-an-empty-outbox` — el hermano: el MISMO fetch, leído con signos opuestos.

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). El propio ticket dice que su escenario (horas sin red y un fallo local al volver) no se monta a mano. Lo cubre `MigrationRunnerTests`.
