---
id: reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last
status: done
priority: medium
area: "modo-nube, migración"
created: 2026-09-22
updated: 2026-09-23
source: "medido al implementar `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last` (2026-09-22): el gemelo de la espera de SUBIDA, con la misma forma y sin arreglar"
---

# En la espera de subida, un fallo de iCloud de UNA pasada cobra las horas que la espera llevaba por otra cosa

## El problema, en lenguaje de usuario

Llevo tres horas esperando a que mis datos suban a iCloud, sin haber entrado a iCloud todavía. La app espera, que es
lo correcto. Entro a iCloud, y en esa primera pasada el espejo contesta «no autenticado» —cosa habitual justo al
iniciar sesión, y que se arregla sola en la siguiente—. En vez de reintentar, la app cancela la vuelta **en ese mismo
instante** y me dice que iCloud no recibió todos mis datos.

Si eso me hubiera pasado a los dos minutos de empezar, habría esperado y reintentado.

## Por qué pasa (medido el 2026-09-22)

Es el **gemelo exacto** de `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last`, en la otra espera.
`MigrationRunner.observeReverseUploadWait` junta dos cosas de procedencias distintas:

- `stalled = observedAt - lastProgressAt` es el tiempo SIN AVANZAR —sin que la cifra de pendientes baje—, venga de
  donde venga. Tres horas sin cuenta iCloud lo llenan igual que tres horas de espejo roto.
- `blocker.stallCause` es de **ESTA** observación, la última (`executor.reverseUploadBlocker()`).

`MigrationStateMachine` aplica el presupuesto de la causa actual al tiempo acumulado
(`guard stalled >= budget`, arista `.reverseUpload + .reverseUploadStalled`). Con 3 h acumuladas y una causa que elige
el techo corto (900 s), sale a la primera: sin histéresis, sin segunda observación y sin un solo reintento.

**El camino está medido, no inferido.** `ReverseUploadBlockerLogic.decide` devuelve `.icloudOff` (techo LARGO) sin
cuenta iCloud, y `.icloudUnusable` (techo CORTO) en cuanto `mirrorReportedNotAuthenticated` se enciende. La transición
de uno a otro es justo lo que pasa cuando alguien entra a iCloud tras horas esperando — y ese testigo «se apaga con
cualquier evento con éxito» según su propia documentación, o sea que el propio código lo trata como pasajero.

## Qué hay que hacer

Lo mismo que se hizo en el techo previo al montaje, y con el mismo mecanismo, que ya está escrito y probado:

1. **Reloj por causa**: el techo corto solo cuenta el tiempo acumulado bajo ESA causa, como racha consecutiva. Dos
   campos aditivos en el journal, al lado de `reverseUploadProgressAt`.
2. **El techo largo sigue por encima con cualquier causa** (`fase >= 72 h OR causa >= 15 min`). Sin esa mitad, dos
   causas definitivas que se alternen re-sellan el reloj corto indefinidamente y la espera vuelve a no tener techo.
3. **Un solo mecanismo para todos los motivos**, como decidió Jürgen para el gemelo.

**No es copiar el diff**: la espera de subida tiene una noción de AVANCE que la otra no tiene —la cifra de pendientes
que baja—, y el reloj de causa tiene que convivir con ese re-sellado. Un avance real reinicia los dos relojes.

## Paso 0 — resuelto (2026-09-23, modo autónomo)

El detalle está en el encargo (`encargos/lanzados/2026-09-23-reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last.md`).
Lo que cambia respecto a lo que pedía este ticket, y por qué:

- **Tres relojes, no dos.** Este ticket se escribió el 22-sep con el molde de ese día (fase + causa). Al día siguiente
  `alternating-definitive-causes-never-reach-the-short-ceiling` midió que con el reloj de causa dos motivos definitivos
  turnándose no vencen nunca el corto. El mecanismo único de hoy es: avance (72 h) · «cualquier motivo definitivo»
  (15 min) · causa (solo el texto).
- **Acumulado con pausa, no racha.** Lo tumbó la review del gemelo con el re-kick de 30 s.
- `icloudOff` y `unknown` pausan los dos acumulados; un avance los reinicia.
- Sin texto nuevo: medido, el de `stalled` no afirma días ni motivo y vale también para los motivos mezclados.

## Qué se toca

| Fichero | Qué cambia |
|---|---|
| `MigrationState.swift` | Schema 15: cinco campos aditivos y `clearReverseUploadCeiling()` para los siete `reverseUpload*` |
| `MigrationRunner.swift` | `observeReverseUploadWait` con los tres relojes, `reverseUploadExitReason` (el texto lo elige el techo que venció) y `reverseUploadExitDetail` (el canario separa `mixedCauses` de las 72 h); el helper en los cinco sitios de limpieza |
| `MigrationStateMachine.swift` | El evento trae `definitiveStalledSeconds`; salida = `avance ≥ 72 h OR definitivo ≥ 900 s`; `…UnknownBudgetSeconds` → `…ProgressBudgetSeconds`; predicado del corto en la policy |
| `MetricsService.swift` / `CloudSyncEngine.swift` | Canario de espera con dos tramos; rastro con tres relojes |
| `ICloudCutoverGateLogic.swift` | Solo docblocks: `abortReason` ya no es lo que se journalea; `stalled` no puede afirmar días |

## Review adversarial (cuatro lentes)

Sin defectos altos. Lo que cambió por ella:

1. **El canario de salida mezclaba tres salidas bajo `stalled`** (telemetría). Ahora las de 15 min con motivos
   turnándose salen como `mixedCauses`, el nombre de la subida del snapshot. El journal sigue con `stalled`: a la
   persona le vale el mismo texto.
2. **Dos mutantes sobrevivían** (tests): el reloj de causa confundido con el de lo definitivo cuando el motivo cambia
   UNA vez, y el reinicio tras avance de lo acumulado en PAUSA. Dos tests nuevos, más cinco que faltaban: muestra
   ilegible con motivo, fila v14 sembrada, sello futuro, hueco no observado y los dos sitios de limpieza sin test.
3. Docblocks de `ReverseUploadBlocker.abortReason` y `ReverseAbortReason.stalled` que ya mentían.
4. `qa/coverage-index.json` sin tocar: corregido.

**Fuera, con ticket:** `stall-clock-charges-a-closed-app-gap-to-a-one-off-cause` — un tramo abierto sigue contando
con la app cerrada, y aquí la señal de CloudKit vive en memoria. Es de las cinco etapas a la vez, no de esta.
**Aceptado sin ticket:** el canario de ESPERA sigue sin test de cableado (ya lo recoge
`stall-canaries-have-no-test-for-which-clock-they-publish`), y en la salida mezclada la nota no repite el consejo de
liberar espacio que la pantalla de espera sí dio (raro: exige errores de CloudKit que vayan y vengan).

## Mutantes

20 de la familia del techo: **19 muertos y 1 equivalente**. El equivalente quita solo la ternaria `advanced ? nil :` del
ACUMULADO del reloj de causa: con la causa sellada a `nil`, `CauseStallClock.observe` no lee ese acumulado en ninguna
rama; las tres ternarias juntas sí mueren. Dos de los muertos (el reloj de causa confundido con el de lo definitivo y el
acumulado en pausa que sobrevivía al avance) sobrevivían antes de los tests que pidió la review.

## Criterios de aceptación

- [x] Un `.icloudUnusable` aislado tras una espera larga por otra causa **reintenta al menos una vez** antes de
      cancelar la vuelta. → `reverseUploadClocks_anIsolatedUnusableAfterHoursWithoutAccount_retriesInsteadOfLeaving`
- [x] Un `icloudFull` repetido sigue saliendo a los 900 s de espera REAL con esa causa.
      → `reverseUploadClocks_aRepeatedFullStillLeavesAt900SecondsOfItsOwn` (899 espera, 900 sale)
- [x] La falta de cuenta iCloud conserva su techo largo, y un AVANCE de la cifra sigue reiniciando los dos relojes.
      → `reverseUploadClocks_aWaitWithoutAccount_pausesInsteadOfResetting`, `…_anAdvance_resetsBothAccruedClocks`,
      `…_anAdvance_resetsTheCauseClockToo_theTextSaysStalled`, `…_anAdvanceAfterAPause_dropsWhatWasAccrued`
- [x] Test que siembre una espera larga con una causa y observe con otra: hoy sale al instante y debe holdear.
      → el primero (observada) y `reverseUploadClocks_aV14RowMidWait_startsTheShortCeilingNow` (sembrada)
- [x] Test de que las causas alternándose siguen topando con el techo largo. → `reverseUploadStalled_longCeiling_appliesWithAnyCause`
      y `reverseUploadClocks_theLongCeiling_leavesWithAnyCause_andTheTextIsStalled`. Y, con el mecanismo de hoy, las
      dos definitivas turnándose topan antes con el corto: `…_alternatingDefinitiveCauses_leaveAtTheShortCeiling_withTheGenericText`.

## Device-QA

No hace falta guion: el escenario (horas sin cuenta de iCloud y el `notAuthenticated` de una pasada justo al entrar)
no se monta a voluntad en un iPhone. Lo cubren `MigrationRunnerTests` y la batería de mutantes.

## Relacionado

- `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last` — el gemelo, ya arreglado; su implementación es
  el molde, con la salvedad del avance.
- `reverse-upload-has-no-ceiling-and-no-exit` — el que creó esta espera y su techo.
- `reverse-upload-ceiling-trusts-a-clock-set-back-during-the-wait` — otro defecto del mismo reloj, independiente.
