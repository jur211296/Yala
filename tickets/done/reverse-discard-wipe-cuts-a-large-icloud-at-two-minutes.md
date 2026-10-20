---
id: reverse-discard-wipe-cuts-a-large-icloud-at-two-minutes
status: done
priority: high
area: "nube, vuelta a iCloud"
created: 2026-10-19
updated: 2026-10-20
qa-status: needs-testing
source: tarjeta del tablero `tablero-volver-a-icloud-empezar-sin-ellos-falla-9ttd` (QA guiado del 2026-10-19, A · 4nt6)
---

# «Volver a iCloud › Empezar sin ellos» fallaba con un iCloud grande: el borrado se cortaba a los 2 minutos

## Qué le pasaba al usuario

Con 1.541 movimientos de Yala en el iCloud del teléfono, «Empezar sin ellos › Borrar y volver a iCloud» se quedaba
minutos en «Dónde viven tus datos» con «Volver a iCloud» apagado y sin decir nada, y terminaba en «No pudimos terminar
de borrar… Revisa tu conexión». Al repetir, el aviso contaba 344: el primer intento había borrado ~1.200.

## Causa (medida en código)

`ICloudPersonalCorpusProbe.deleteForeignRecordsFromCloudKit` tenía un plazo TOTAL de 120 s
(`foreignWipeDeadline`) y devolvía `wipeDeadline` al pasarlo, avanzara o no. El controller convertía cualquier motivo en
el mismo texto, que culpaba a la conexión. No había progreso en pantalla. Además, un registro que CloudKit daba por
ocupado (`zoneBusy`, `requestRateLimited`) cortaba el recorrido entero.

## Arreglo

- **Sin plazo total.** El recorrido (`runForeignWipe`, puro sobre `ForeignWipeIO`) sigue mientras avance: cada página
  leída o tanda con algún borrado reinicia el plazo, y solo se corta tras `foreignWipeStallLimit` (120 s) **sin
  avanzar** (`.stalled`).
- Lo que CloudKit da por ocupado se repite tras su `retryAfterSeconds` (o 2 s); esa espera no cuenta como avance.
- **Progreso visible:** el botón «Volver a iCloud» dice «Borrando los datos de antes… N hasta ahora» mientras borra.
- **Texto:** solo la falta de red (`networkUnavailable`/`networkFailure`) habla de la conexión. El corte por falta de
  avance y cualquier otro fallo dicen que lo borrado se queda borrado y que al reintentar sigue con lo que falta
  (`storage.revert.prior.wipeStopped`, 16 idiomas). El canario conserva los motivos y gana `wipeStalled`.

Tests: `YalaTests/CloudSync/ForeignWipeLoopTests` (corpus de 1.541 ajenos + 300 propios con 30 s por tanda: termina en
un intento y supera de largo los 120 s viejos; ocupado se repite; control: sin avance se corta como `.stalled`; el corte
se mide desde el último avance; sin red; registro ilegible), `ReverseICloudPriorDataTests` (clasificación por registro y
cableado) y `ReverseICloudPriorDataUITests` (sin red, parado y progreso, con `-uitest-reverse-prior-icloud-wipe`).

## Lo que no cubre

- **El recuento previo del aviso** (`foreignScanDeadline = 60`, total) tiene el mismo patrón de plazo fijo; con 1.541
  registros contó bien en el QA, así que no se tocó: `reverse-prior-icloud-scan-has-a-fixed-deadline` (backlog).
- Una petición de CloudKit colgada no se corta entre medias: la acota CloudKit.

## Device-QA (Jürgen, iPhone de QA, Yala Dev contra staging)

Montaje: un iCloud con **1.500 movimientos o más** de Yala que la cuenta en la nube no tenga (el de la prueba 4nt6), y
una cuenta nacida en la nube (cuenta B).

1. Ajustes › «Dónde viven tus datos» › «Volver a iCloud».
2. En «Tu iCloud ya tiene datos de Yala», toca «Empezar sin ellos» › «Borrar y volver a iCloud».
3. **Esperado:** el botón dice «Borrando los datos de antes… N hasta ahora» y la cifra sube.
4. **Esperado:** termina en **un solo intento** y la vuelta a iCloud sigue sola (la tarjeta pasa a la vuelta).
5. Si se corta: el texto no debe decir «Revisa tu conexión» salvo que el teléfono esté sin red. Anota la cifra.

Cerrado en el QA guiado 2026-10-20 (tanda del TestFlight 19): Yala Dev: «Empezar sin ellos» borró 1.501 registros de iCloud en un solo intento y la vuelta siguió sola.
